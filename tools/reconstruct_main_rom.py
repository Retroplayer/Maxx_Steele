"""Create a labeled KickAssembler reconstruction of the original main ROM.

Uses the supplied listing ONLY to locate candidate instructions. Decoding,
relative targets, and emitted data come from the hash-checked binary. Curated
annotations live in rom_annotations.py. Generate into a scratch directory when
reviewing changes: do not overwrite subsequently hand-edited assembly blindly.
"""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
from analyze_speech import WORDS
from verify_remote import ROM_SHA256
from rom_annotations import SECTIONS, ROUTINES, DATA_LABELS, PHRASE_NAMES, ZP_NAMES, PORTS, BIASES, INLINE_NOTES

ROOT=Path(__file__).resolve().parents[1]
MODES_SIZE={'imp':1,'acc':1,'imm':2,'zpg':2,'zpx':2,'zpy':2,'inx':2,'iny':2,'rel':2,'abs':3,'abx':3,'aby':3,'ind':3}

def identifier(text):
    return re.sub(r'[^A-Z0-9]+','_',text.upper()).strip('_')

def reconstruct(rom,listing,out):
    assert len(rom)==65536 and hashlib.sha256(rom).hexdigest()==ROM_SHA256
    opcodes=MPU().disassemble
    mnemonics={name for name,mode in opcodes if name!='???'}
    code=set(); corrections=[]
    for line in listing.splitlines():
        match=re.match(r'([0-9A-Fa-f]{8}):\s*([0-9A-Fa-f]+)\s+(\w+)',line)
        if not match or match[3] not in mnemonics:continue
        pc=0xE000+int(match[1],16)
        if opcodes[rom[pc]][0]!=match[3]:
            corrections.append({'pc':f'{pc:04X}','issue':'listing opcode/position mismatch','listed':match[3],'binary':opcodes[rom[pc]][0]})
        else:code.add(pc)
    # Known shifted labels: recover the WHOLE subroutine, not operand bytes.
    code={pc for pc in code if not 0xE555<=pc<0xE574}
    pc=0xE555
    while pc<0xE574:
        code.add(pc);pc+=MODES_SIZE[opcodes[rom[pc]][1]]
    assert pc==0xE574
    code.add(0xF07C)
    assert rom[0xF07C:0xF07E]==bytes([0xF0,0x12])
    corrections.append({'pc':'F07C','issue':'missing BEQ mnemonic recovered from binary','target':'F090'})
    occupied={}
    direct_targets=set();call_targets=set()
    for pc in sorted(code):
        name,mode=opcodes[rom[pc]];size=MODES_SIZE[mode]
        for byte in range(pc,pc+size):
            assert byte not in occupied,(hex(byte),occupied.get(byte),pc)
            occupied[byte]=pc
        if mode=='rel':target=(pc+2+(rom[pc+1] if rom[pc+1]<128 else rom[pc+1]-256))&65535
        elif name in ('JSR','JMP') and mode=='abs':
            target=rom[pc+1]|rom[pc+2]<<8
            if name=='JSR':call_targets.add(target)
        else:continue
        assert target in code,(hex(pc),name,hex(target))
        direct_targets.add(target)
    # All residual ranges are explicit known data. No opaque code .byte fallback.
    gaps=[];pc=0xE000
    while pc<0x10000:
        if pc in occupied:pc+=1;continue
        end=pc+1
        while end<0x10000 and end not in occupied:end+=1
        gaps.append((pc,end));pc=end
    expected=[(0xE000,0xE011),(0xE01C,0xE041),(0xE54D,0xE555),(0xE5EC,0xE600),
              (0xE6B5,0xE6CE),(0xF145,0xF151),(0xF15C,0xF164),(0xF2A8,0xF2C4),
              (0xF372,0xF378),(0xF4DB,0xF64E),(0xF756,0xF75E),(0xF7F8,0xF8CE),
              (0xFA90,0xFAA4),(0xFDE6,0x10000)]
    assert gaps==expected,gaps
    assert SECTIONS[0][0]==0xE000 and SECTIONS[-1][1]==0x10000
    for index,(start,end,stem,description) in enumerate(SECTIONS):
        if index:assert SECTIONS[index-1][1]==start
        assert start not in occupied or start in code
        assert end not in occupied or end in code
    symbols={pc:name for pc,(name,_) in ROUTINES.items()}
    for pc in ROUTINES:assert pc in code,hex(pc)
    symbols.update(DATA_LABELS)
    for pc in direct_targets:
        symbols.setdefault(pc,('Routine_' if pc in call_targets else 'L_')+f'{pc:04X}')
    for start,end,stem,_ in SECTIONS:
        symbols.setdefault(start,'Section_'+stem.replace('_',''))
    # Identify all 17 stock phrase boundaries by the actual $FF terminators.
    phrases=[];pc=0xF5F3
    for index,name in enumerate(PHRASE_NAMES,16):
        start=pc;values=[]
        while rom[pc]!=0xFF:values.append(rom[pc]);pc+=1
        pc+=1;phrases.append((start,pc,index,values));symbols[start]='Phrase'+name
    assert pc==0xF64E
    # Tune headers and all unique stream starts from their actual words.
    headers=[];streams=set()
    for index in range(9):
        address=rom[0xFDEC+index]|rom[0xFDF5+index]<<8
        pointers=[rom[address+j]|rom[address+j+1]<<8 for j in (0,2,4)]
        headers.append((address,index,pointers));symbols[address]=f'Tune{index}Pointers'
        for voice,target in enumerate(pointers):
            if 0xE000<=target<0xFFFA:
                streams.add(target);symbols.setdefault(target,f'Tune{index}Voice{voice}')
    symbols[0xFF12]='SilentTuneStream'
    # Every fixed ROM data operand gets a symbolic label, including biased bases.
    for pc in sorted(code):
        name,mode=opcodes[rom[pc]]
        if mode in ('abs','abx','aby') and name not in ('JSR','JMP'):
            address=rom[pc+1]|rom[pc+2]<<8
            if address>=0xE000 and address not in BIASES:
                assert address not in occupied or address in code,(hex(pc),hex(address))
                symbols.setdefault(address,'Data_'+f'{address:04X}')
    assert len(set(symbols.values()))==len(symbols)
    out.mkdir(parents=True,exist_ok=True);(out/'includes').mkdir(exist_ok=True)
    zero_roles={int(r['address'],16):r['role'] for r in csv.DictReader((ROOT/'docs/zero-page-map.csv').open())}
    lines=['// Stock firmware RAM and CPU-addressed ports. Values intentionally preserve the original layout.',
           '// Candidate/free locations are not allocated by this assembly project. See docs/ram-ownership.md.','']
    for address,name in sorted(ZP_NAMES.items()):
        lines.append(f'.const ZP_{name} = ${address:02x} // {zero_roles.get(address,"Role unresolved")}')
    lines+=['','// Existing buffers; 6502 hardware stack remains in page $01.',
            '.const RAM_WARM_MARKER = $0100','.const USER_PROGRAM = $0200',
            '.const USER_PROGRAM_END = $0400','.const USER_TUNE = $0400','.const USER_PHRASES = $0500',
            '.const MODE_IMMEDIATE = 0','.const MODE_LEARN = 1','.const MODE_PROGRAM = 2',
            '.const MODE_EXECUTE = 3','.const MODE_GAME = 4','',
            '// Read/write functions at one address can differ. These are not confirmed VIA registers.']
    for address,name in PORTS.items():lines.append(f'.const {name} = ${address:04x}')
    lines+=['','// Speech IDs and addresses belong to the LC8100/LC3100 subsystem, not CPU RAM/ROM.']
    for index,word in enumerate(WORDS):
        lines.append(f'.const VOC_{identifier(word)} = ${index:02x} // {word}')
    for index,word in enumerate(WORDS[:140]):
        address=rom[0xF567+index]<<8|rom[0xF4DB+index]
        lines.append(f'.const SPADDR_{identifier(word)} = ${address:04x} // external speech data address')
    presets=list(csv.DictReader((ROOT/'docs/head-messages.csv').open()))
    lines+=['','// Fixed four-glyph head message IDs. The head receives segment bytes, not ASCII.']
    for row in presets:lines.append(f'.const MSG_{identifier(row["approximate_LED_text"])} = ${int(row["preset_decimal"]):02x} // {row["meaning"]}')
    (out/'symbols.asm').write_text('\n'.join(lines)+'\n')
    # Data directives are keyed by start; every byte is explicitly accounted for.
    data={}
    def put(address,size,line,comment=''):
        assert address not in data,hex(address)
        for byte in range(address,address+size):assert byte not in occupied,hex(byte)
        data[address]=(size,line,comment)
    def byte_rows(start,end,comment=''):
        p=start
        while p<end:
            # Preserve any intervening label at its exact data boundary.
            n=min(8,end-p)
            label_offsets=[a-p for a in symbols if p<a<p+n]
            if label_offsets:n=min(label_offsets)
            put(p,n,'.byte '+', '.join(f'${v:02x}' for v in rom[p:p+n]),comment if p==start else '')
            p+=n
    put(0xE000,17,'.text "(c) 1984 CBS Toys"','17 bytes; also copied into the warm-start marker.')
    data_label_extra={0xE011:'CopyrightTextEnd',0xE041:'InitialRAMTableEnd'}
    # Reset table mirrors the exact RAM $72-$96 structure.
    put(0xE01C,4,'.byte $82, $00, $00, $80','Headlamp divider, inactivity bytes, and empty mailbox.')
    for address,name in [(0xE020,'NMIDefault'),(0xE022,'IRQDefault'),(0xE024,'MainModeEntry')]:put(address,2,'.word '+name)
    tasks=['MusicIRQ','MusicIRQ','MusicIRQ','IRQRestore','TimerIRQ','HeadlampIRQ','IRQRestore','SpeechIRQ']
    put(0xE026,8,'.byte '+', '.join(f'<({name}-1)' for name in tasks),'IRQ task low bytes: RTS requires target minus one.')
    put(0xE02E,8,'.byte '+', '.join(f'>({name}-1)' for name in tasks),'Corresponding IRQ task high bytes.')
    for address,line in [(0xE036,'ServiceDefault'),(0xE038,'$1000'),(0xE03A,'ReadOperandDefault'),(0xE03C,'SpeakVocabularyDefault'),(0xE03E,'GamesEntry')]:put(address,2,'.word '+line)
    put(0xE040,1,'.byte $ff','Initial battery countdown/state.')
    byte_rows(0xE54D,0xE555,'Reverse-execution operation remap: left/reverse/forward/right/wrist/arm pairs.')
    for index,address in enumerate(range(0xE5EC,0xE600)):
        put(address,1,f'.byte ${rom[address]:02x}',f'Operand upper bound, operation/table index ${index:02x}.')
    for index,address in enumerate(range(0xE6B5,0xE6CE)):
        put(address,1,f'.byte ${rom[address]:02x}',f'Remote key index {index}; encoded UI/mode action, not raw RF payload.')
    for index,address in enumerate(range(0xF145,0xF151)):
        put(address,1,f'.byte ${rom[address]:02x}',f'Music pitch glyph {index}; lookup uses biased base MusicNoteGlyphs-$f4.')
    byte_rows(0xF15C,0xF164,'Duration entries 1..8. Index zero deliberately reads the RTS byte at $F15B.')
    byte_rows(0xF2A8,0xF2B4,'Tone-period high bytes; negative-looking 8-bit index is added to a base biased by $f4.')
    byte_rows(0xF2B4,0xF2C0,'Tone-period low bytes, same biased indexing.')
    byte_rows(0xF2C0,0xF2C4,'Encoded channel control bytes: three tone voices plus fourth initialization entry.')
    byte_rows(0xF372,0xF375,'Per-voice AND masks for clearing effect-active bits.')
    byte_rows(0xF375,0xF378,'Per-voice OR masks for setting effect-active bits.')
    for index,word in enumerate(WORDS[:140]):
        put(0xF4DB+index,1,f'.byte <SPADDR_{identifier(word)}',f'Vocabulary {index}: {word}')
        put(0xF567+index,1,f'.byte >SPADDR_{identifier(word)}',f'Vocabulary {index}: {word}')
    for start,end,index,values in phrases:
        tokens=[f'VOC_{identifier(WORDS[value])}' for value in values]+['$ff']
        put(start,end-start,'.byte '+', '.join(tokens),f'Phrase {index}: '+ ' '.join(WORDS[value] for value in values))
    byte_rows(0xF756,0xF75E,'Packed-BCD conversion adjustment bytes.')
    for base,position in [(0xF7F8,3),(0xF818,2),(0xF838,1),(0xF858,0)]:
        for index,row in enumerate(presets):
            put(base+index,1,f'.byte ${rom[base+index]:02x}',f'Message {index:02d} {row["approximate_LED_text"]}: glyph {position}.')
    for start,end,comment in [(0xF878,0xF889,'First command-label glyphs.'),(0xF889,0xF897,'Additional command-label glyphs.'),
                              (0xF897,0xF8AA,'Second command-label glyphs.'),(0xF8AA,0xF8BE,'Command formatting selectors.'),
                              (0xF8BE,0xF8CE,'Digit glyphs 0..F; bit 0 is decimal point. Stock 9 lacks bottom segment.')]:byte_rows(start,end,comment)
    for start,end in [(0xFA90,0xFA94),(0xFA94,0xFA98),(0xFA98,0xFA9C),(0xFA9C,0xFAA0),(0xFAA0,0xFAA4)]:byte_rows(start,end,'Game difficulty-dependent parameters; precise meanings remain partly unresolved.')
    put(0xFDE6,6,'.fill 6, $ff','Six unused-looking fill bytes, retained exactly; not yet a promised free-code area.')
    put(0xFDEC,9,'.byte '+', '.join(f'<Tune{i}Pointers' for i in range(9)),'Tune-header low-byte table.')
    put(0xFDF5,9,'.byte '+', '.join(f'>Tune{i}Pointers' for i in range(9)),'Tune-header high-byte table.')
    for address,index,pointers in headers:
        names=['USER_TUNE' if target==0x0400 else symbols[target] for target in pointers]
        put(address,6,'.word '+', '.join(names),f'Tune {index}: voice 0,1,2 stream pointers.')
    header_bytes={a for start,index,ptrs in headers for a in range(start,start+6)}
    for start in sorted(streams):
        end=min([a for a in list(streams)+[h[0] for h in headers]+[0xFFFA] if a>start])
        assert not any(a in header_bytes for a in range(start,end))
        assert (end-start)%2==0
        for address in range(start,end,2):
            duration,note=rom[address:address+2]
            put(address,2,f'.byte ${duration:02x}, ${note:02x}',
                'Stream end: duration=0, note=0.' if duration==note==0 else 'Encoded duration, note/control pair.')
    put(0xFFFA,2,'.word NMIEntry','Hardware NMI vector.')
    put(0xFFFC,2,'.word ResetEntry','Hardware reset vector.')
    put(0xFFFE,2,'.word IRQEntry','Hardware IRQ/BRK vector.')
    all_data_bytes={}
    for start,(size,line,comment) in data.items():
        for address in range(start,start+size):
            assert address not in all_data_bytes,hex(address)
            all_data_bytes[address]=start
    assert set(all_data_bytes)=={a for a in range(0xE000,0x10000) if a not in occupied}
    def mem(address):
        if address in BIASES:return BIASES[address]
        if address in ZP_NAMES:return 'ZP_'+ZP_NAMES[address]
        if address in PORTS:return PORTS[address]
        if address==0x100:return 'RAM_WARM_MARKER'
        if address in (0x400,0x401):return 'USER_TUNE'+(' + 1' if address==0x401 else '')
        if address==0x500:return 'USER_PHRASES'
        if address in symbols:return symbols[address]
        return f'${address:04x}'
    # Deliberately symbolic split pointer loads whose low/high provenance is known.
    immed={0xE582:'<(USER_PROGRAM-$80)',0xE586:'>(USER_PROGRAM-$80)',
           0xE2E0:'>(USER_PROGRAM_END-2-$80)',0xE2E6:'<(USER_PROGRAM_END-2-$80)',
           0xE555:'>(USER_PROGRAM-$80)',0xE55D:'<(USER_PROGRAM-$80)',
           0xF38E:'>USER_PHRASES',0xF41F:'>USER_PHRASES',
           0xF426:'<PhraseHelloIntro',0xF42A:'>PhraseHelloIntro',
           0xF2C6:'<(MusicOscillatingEffectIRQ-1)',0xF2C8:'>(MusicOscillatingEffectIRQ-1)',
           0xF2CE:'<(MusicSweepEffectIRQ-1)',0xF2D0:'>(MusicSweepEffectIRQ-1)',
           0xF2D4:'<(MusicRandomEffectIRQ-1)',0xF2D6:'>(MusicRandomEffectIRQ-1)',
           0xF2E0:'<(MusicDecayEffectIRQ-1)',0xF2E2:'>(MusicDecayEffectIRQ-1)'}
    # F426 is LDA #F3 and F42A is LDA #F5; verify all replacements use immediates.
    for address in immed:assert opcodes[rom[address]][1]=='imm',(hex(address),opcodes[rom[address]])
    def instruction(pc):
        op,mode=opcodes[rom[pc]];op=op.lower();operand=''
        if mode=='imm':operand='#'+immed.get(pc,f'${rom[pc+1]:02x}')
        elif mode in ('zpg','zpx','zpy'):
            operand=mem(rom[pc+1])
            if mode!='zpg':operand+=', '+mode[-1]
        elif mode=='inx':operand='('+mem(rom[pc+1])+', x)'
        elif mode=='iny':operand='('+mem(rom[pc+1])+'), y'
        elif mode=='rel':
            target=(pc+2+(rom[pc+1] if rom[pc+1]<128 else rom[pc+1]-256))&65535
            operand=symbols[target]
        elif mode in ('abs','abx','aby','ind'):
            address=rom[pc+1]|rom[pc+2]<<8;operand=mem(address)
            if mode=='ind':operand='('+operand+')'
            elif mode in ('abx','aby'):operand+=', '+('x' if mode=='abx' else 'y')
            if mode!='ind' and op not in ('jsr','jmp'):op+='.abs'
        return op+(' '+operand if operand else '')
    def add_label(lines,pc):
        if pc in data_label_extra:lines.append(data_label_extra[pc]+':')
        if pc in symbols:
            lines.append('')
            if pc in ROUTINES:
                lines.append('// '+ROUTINES[pc][1])
                if pc in (0xFA0C,0xFA01,0xF9EA):lines.append('// Shared helper: proximity to game code is not proof of exclusive game ownership.')
            lines.append(symbols[pc]+':')
    main=['// Reconstructed stock Maxx Steele main ROM. KickAssembler 5.25 syntax.',
          '// Source bytes: SHA-256 '+ROM_SHA256,
          '// Layout is intentionally locked for a byte-identical baseline; no optimization/removal.',
          '.encoding "ascii"','#import "symbols.asm"','* = $e000 "Main ROM"','ROMStart:','']
    section_stats=[]
    for start,end,stem,description in SECTIONS:
        lines=['// '+description,f'// Original CPU range ${start:04x}-${end-1:04x}.',
               f'.assert "{stem} start", *, ${start:04x}']
        pc=start;instructions=0;data_count=0
        while pc<end:
            add_label(lines,pc)
            if pc in code:
                op,mode=opcodes[rom[pc]];size=MODES_SIZE[mode]
                text=instruction(pc)
                comment=f'{pc:04X}'
                if pc in INLINE_NOTES:comment+='; '+INLINE_NOTES[pc]
                if pc==0xF07C:comment+='; missing BEQ restored from binary'
                if pc in (0xF15B,):comment+='; RTS opcode $60 is also duration-table index zero'
                lines.append(f'    {text:<54} // {comment}')
                pc+=size;instructions+=1
            else:
                assert pc in data,hex(pc)
                size,line,comment=data[pc]
                lines.append('    '+line+' // '+f'{pc:04X}'+('; '+comment if comment else ''))
                pc+=size;data_count+=size
        assert pc==end
        lines.append(f'.assert "{stem} end", *, ${end:05x}')
        (out/'includes'/f'{stem}.asm').write_text('\n'.join(lines)+'\n')
        main.append(f'#import "includes/{stem}.asm"')
        section_stats.append({'file':f'includes/{stem}.asm','start':f'{start:04X}','end_exclusive':f'{end:05X}',
                              'instructions':instructions,'data_bytes':data_count,'description':description})
    main+=['','ROMEnd:','.assert "Complete ROM length", ROMEnd-ROMStart, $2000',
           '// The common effect-setup path relies on these handlers sharing a high byte.',
           '.assert "Effect handler page sweep", >MusicSweepEffectIRQ, >MusicDecayEffectIRQ',
           '.assert "Effect handler page random", >MusicRandomEffectIRQ, >MusicDecayEffectIRQ',
           '.assert "Effect handler page oscillating", >MusicOscillatingEffectIRQ, >MusicDecayEffectIRQ',
           '.assert "User phrase page alignment", <USER_PHRASES, 0',
           '.assert "User tune page alignment", <USER_TUNE, 0']
    (out/'main.asm').write_text('\n'.join(main)+'\n')
    report={'mapped_rom_sha256':ROM_SHA256,'payload_sha256':hashlib.sha256(rom[0xE000:]).hexdigest(),
            'payload_bytes':8192,'instruction_count':len(code),'instruction_bytes':len(occupied),
            'data_bytes':len(all_data_bytes),'code_data_coverage_bytes':len(occupied)+len(all_data_bytes),
            'opaque_binary_includes':0,'direct_control_targets_checked':len(direct_targets),
            'listing_corrections':corrections,'sections':section_stats,
            'limits':'Complete byte coverage and direct-target boundary checks; semantic/indirect control-flow coverage remains partial. Game removal and relocation are not performed.'}
    (out/'coverage.json').write_text(json.dumps(report,indent=2)+'\n')
    with (out/'routines.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['address','label','description','known_JSR_target'])
        for pc in sorted(code):
            if pc in call_targets or pc in ROUTINES:
                w.writerow([f'{pc:04X}',symbols.get(pc,f'Routine_{pc:04X}'),ROUTINES.get(pc,('','Semantics not yet fully classified'))[1],pc in call_targets])
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rom',type=Path,required=True)
    p.add_argument('--listing',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();r=reconstruct(a.rom.read_bytes(),a.listing.read_text(),a.output)
    print(json.dumps({k:r[k] for k in ('instruction_count','instruction_bytes','data_bytes','code_data_coverage_bytes')},indent=2))
