from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parent.parent
im=Image.new('RGBA',(1024,1024),(0,0,0,0))
d=ImageDraw.Draw(im)
d.rounded_rectangle((75,75,949,949),radius=190,fill='#245B42')
d.rounded_rectangle((287,221,737,803),radius=46,outline='#D6E7B8',width=22)
d.line((355,361,666,361),fill='#D6E7B8',width=18)
d.line((355,485,666,485),fill='#D6E7B8',width=18)
d.line((467,609,666,609),fill='#D6E7B8',width=18)
d.ellipse((337,687,387,737),fill='#D6E7B8')
im.save(root/'assets/Daftar.png')
im.save(root/'assets/Daftar.icns',format='ICNS')
