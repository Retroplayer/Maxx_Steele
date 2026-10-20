#!/usr/bin/python3
"""Check Maxx pinout, native schematic/PCB parity, and retained KFF core nets."""
from pathlib import Path
import json,re,xml.etree.ElementTree as E
import pcbnew as k
ROOT=Path(__file__).resolve().parents[1]
orig=E.parse(ROOT/'upstream/KungFuFlash.xml').getroot()
new=E.parse(ROOT/'reports/schematic-netlist.xml').getroot()
def mapping(root,exclude=()):
 out={}
 for n in root.findall('./nets/net'):
  nodes={(x.attrib['ref'],x.attrib['pin']) for x in n.findall('node') if x.attrib['ref'] not in exclude}
  for node in nodes:out[node]=(n.attrib['name'],nodes)
 return out
excluded=['U1','Q1','R3','R4']
a,c=mapping(orig,excluded),mapping(new,excluded)
for node,(name,nodes) in a.items():
 if len(nodes)>1:assert node in c and c[node][1]==nodes,('Retained core net differs',node,name,nodes,c.get(node))
allnets=mapping(new)
# Independent explicit expected connections; these do not rely on PCB pad order.
address_pins=[20,18,17,15,13,11,9,7,8,10,16,6,5,4,3,2]
data_pins=[22,24,26,28,25,23,21,19]
for i,pin in enumerate(address_pins):assert allnets['U1',str(pin)][0]=='/A'+str(i)
for i,pin in enumerate(data_pins):assert allnets['U1',str(pin)][0]=='/CD'+str(i)
for pin,name in [(1,'GND'),(43,'GND'),(41,'+5V'),(12,'/WRB'),(14,'/OEB')]:assert allnets['U1',str(pin)][0]==name
used=set(address_pins+data_pins+[1,43,41,12,14])
for pin in set(range(1,45))-used:
 name,nodes=allnets['U1',str(pin)]
 assert name.startswith('unconnected-') and nodes=={('U1',str(pin))},('Reserved/battery signal must be isolated',pin,name,nodes)
b=k.LoadBoard(str(ROOT/'KungFuMaxx.kicad_pcb'))
assert b.GetCopperLayerCount()==4, 'A0 requires four copper layers'
for fp in b.GetFootprints():
 if fp.GetReference() in ['G***','REF**']:continue
 for pad in fp.Pads():
  if not pad.GetNumber():
   assert pad.GetAttribute()==k.PAD_ATTRIB_NPTH and pad.GetNetCode()==0
   continue
  node=fp.GetReference(),pad.GetNumber()
  assert node in allnets,('Extra PCB pad',node)
  assert pad.GetNetname()==allnets[node][0],('PCB/schematic mismatch',node,pad.GetNetname(),allnets[node][0])
edge=next(f for f in b.GetFootprints() if f.GetReference()=='U1')
pads=list(edge.Pads());assert len(pads)==44 and {p.GetNumber() for p in pads}=={str(i) for i in range(1,45)}
for pad in pads:
 pin=int(pad.GetNumber());index=(pin-1)//2
 assert pad.IsOnLayer(k.F_Cu if pin%2==0 else k.B_Cu)
 assert abs(k.ToMM(pad.GetPosition().x)-(78.228+index*2.54))<.002
 assert not pad.IsOnLayer(k.F_Paste) and not pad.IsOnLayer(k.B_Paste)
oldboard=k.LoadBoard(str(ROOT/'upstream/KungFuFlash.kicad_pcb'))
oldfp={f.GetReference():f for f in oldboard.GetFootprints()}
for fp in b.GetFootprints():
 if fp.GetReference()=='U1':continue
 old=oldfp[fp.GetReference()]
 assert abs(fp.GetPosition().x-old.GetPosition().x)<k.FromMM(.002)
 assert abs(fp.GetPosition().y-old.GetPosition().y)<k.FromMM(.002)
 assert abs(fp.GetOrientationDegrees()-old.GetOrientationDegrees())<.01
result={'copper_layers':4,'retained_core_net_connectivity':'matches original','pcb_schematic_pad_nets':'match','edge_contacts':44,'used_contacts':len(used),'reserved_contacts_isolated':44-len(used),'pitch_mm':2.54,'component_placement':'matches original within 2 um rounding tolerance','pin_12':'WRB -> PA0','pin_14':'OEB -> PA8','pin_39':'VBAT isolated','pin_41':'VSW -> regulator input','physical_insertion_orientation_verified':False,'hardware_tested':False}
(ROOT/'reports/connectivity-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS: core net topology, PCB/schematic nets, 44 unique contacts, face/pitch, 15 isolated reserved pins, and retained placement')
