"""Verify and export all 32 fixed head-message patterns and LCD suggestions."""
import argparse,csv,hashlib
from pathlib import Path
from analyze_head_display import Trace,byte_values
from verify_remote import ROM_SHA256

# LCD suggestions are editorial text, not strings stored in the original ROM.
MESSAGES=[
 ('Song','Song selection','Select song',''),
 ('SPEE','Individual speech sound selection','Select sound',''),
 ('SEnt','Sentence/phrase selection','Select sentence',''),
 ('StAt','Status/settings menu','Robot settings',''),
 ('notE','Direct note-playing mode','Play notes',''),
 ('CLOC','Clock menu/display','Clock',''),
 ('LErn','Learn mode','Learn mode',''),
 ('Prog','Program mode','Program mode',''),
 ('run','Execute mode','Run program',''),
 ('PLAy','Game mode','Play game',''),
 ('CLr','Clear a program step','Clear step',''),
 ('CLrP','Entire program cleared; manual also associates with clearing song','Memory cleared',''),
 ('FULL','Programming storage full','Memory full',''),
 ('StAL','Motor stall','Motor stalled',''),
 ('End','End of program','End of program',''),
 ('bEg','Beginning of program','Start of program',''),
 ('init','Initialize/home command','Return to home',''),
 ('AEoF','Auto-execution on alarm disabled','Auto execution','Off'),
 ('AEon','Auto-execution on alarm enabled','Auto execution','On'),
 ('SEr','Serial program execution','Execution mode','Serial'),
 ('PAr','Parallel program execution','Execution mode','Parallel'),
 ('Pdon','Automatic power-down enabled','Auto power-down','On'),
 ('PdoF','Automatic power-down disabled','Auto power-down','Off'),
 ('EdoF','Edit mode disabled','Edit mode','Off'),
 ('Edon','Edit mode enabled','Edit mode','On'),
 ('UCon','Wrist/arm coupling enabled','Wrist coupling','On'),
 ('UCoF','Wrist/arm coupling disabled','Wrist coupling','Off'),
 ('Ebon','Execute-backwards feature enabled','Run backwards','On'),
 ('EboF','Execute-backwards feature disabled','Run backwards','Off'),
 ('SPon','Verbal prompts enabled; not all speech enabled/disabled','Speech prompts','On'),
 ('SPoF','Verbal prompts disabled; programmed speech remains distinct','Speech prompts','Off'),
 ('bAd','Bad/invalid entry indication; precise context-dependent meaning','Invalid entry',''),
]

def export(rom,output):
 assert hashlib.sha256(rom).hexdigest()==ROM_SHA256
 assert len(MESSAGES)==32
 with output.open('w',newline='') as f:
  w=csv.writer(f);w.writerow(['preset_decimal','preset_hex','approximate_LED_text','glyph_bytes','meaning','LCD_line_1','LCD_line_2'])
  for index,(text,meaning,line1,line2) in enumerate(MESSAGES):
   assert len(line1)<=16 and len(line2)<=16
   glyphs=[rom[base+index] for base in (0xF858,0xF838,0xF818,0xF7F8)]
   result=Trace(rom).run(0xF684,x=index)
   assert byte_values(result)==[0xE3,0xF3,*glyphs,0xE2]
   w.writerow([index,f'{index:02X}',text,' '.join(f'{v:02X}' for v in glyphs),meaning,line1,line2])

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('rom',type=Path);p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();export(a.rom.read_bytes(),a.output);print('Verified 32 original-ROM preset streams; all LCD suggestions fit 16 columns.')
