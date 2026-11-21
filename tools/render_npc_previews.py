#!/usr/bin/env python3
"""Offline approximation of the four procedural 1.1.0 NPC silhouettes.

These PNGs are NOT Garry's Mod screenshots. Geometry/proportions/colors are
transcribed from lua/autorun/client/wotw_generated_models.lua; no game shaders,
weapon effects or actual map lighting are simulated.
Requires: numpy, matplotlib, Pillow. Run from repository root.
"""
from pathlib import Path
import math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import to_rgb
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'previews/1.1.0'
OUT.mkdir(parents=True, exist_ok=True)
STYLES = {
    'pendragon': ('Pendragon Pictures', 285, 138, 3, (37, 26, 30), (77,83,67), (64,71,62), (205,230,160), 7, '#15232b'),
    'walker': ('The Asylum Walker', 155, 145, 4, (75, 60, 19), (34,32,25), (53,49,36), (95,255,65), 8, '#2a251c'),
    'bbc2019': ('BBC 2019 Tripod', 285, 137, 3, (76, 58, 29), (16,28,41), (31,47,58), (50,158,255), 12, '#15212d'),
    'asylum2': ('The Asylum WOTW 2', 200, 136, 4, (58,49,39), (62,38,37), (82,52,46), (243,84,54), 10, '#251d20'),
}

def rgb(c):
    return tuple(min(1, (v/255)*1.75+0.04) for v in c)

def ellipsoid(ax, origin, size, color, resolution=18):
    u = np.linspace(0, 2*np.pi, resolution)
    v = np.linspace(0, np.pi, max(12, resolution//2))
    x = origin[0]+size[0]*np.outer(np.cos(u), np.sin(v))
    y = origin[1]+size[1]*np.outer(np.sin(u), np.sin(v))
    z = origin[2]+size[2]*np.outer(np.ones_like(u), np.cos(v))
    ax.plot_surface(x, y, z, color=rgb(color), shade=True, linewidth=0, antialiased=False, zorder=15)

def segment(ax, a, b, width, color, sides=6):
    a,b=np.asarray(a,float),np.asarray(b,float)
    d=b-a
    if np.linalg.norm(d)<1: return
    d/=np.linalg.norm(d)
    normal=np.cross(d, [0,0,1])
    if np.linalg.norm(normal)<0.01:normal=np.cross(d,[0,1,0])
    normal/=np.linalg.norm(normal)
    other=np.cross(d,normal)
    theta=np.linspace(0,2*np.pi,sides+1)
    circles=np.array([a,b])
    coords=circles[:,None,:]+width*(np.cos(theta)[None,:,None]*normal+np.sin(theta)[None,:,None]*other)
    ax.plot_surface(coords[:,:,0],coords[:,:,1],coords[:,:,2],color=rgb(color),shade=True,linewidth=0,antialiased=False,zorder=9)

def render(kind):
    title,height,radius,legs,head,shell,limb,eye,width,bg = STYLES[kind]
    fig=plt.figure(figsize=(7,7),dpi=130,facecolor=bg)
    ax=fig.add_axes([0.02,0.08,0.96,0.84],projection='3d',facecolor=bg)
    tilt=kind=='walker'
    x,y=np.meshgrid(np.linspace(-190,190,2),np.linspace(-190,190,2))
    surface=0.14*x+0.08*y if tilt else np.zeros_like(x)
    # Grid only: mplot3d sorts a filled ground surface in front of the legs.
    for theta in np.linspace(-160,160,7):
        ax.plot([theta,theta],[-160,160],[(0.14*theta-12.8) if tilt else 0,(0.14*theta+12.8) if tilt else 0],
                color='#7d8589',linewidth=.6,alpha=.32)
        ax.plot([-160,160],[theta,theta],[(-22.4+0.08*theta) if tilt else 0,(22.4+0.08*theta) if tilt else 0],
                color='#7d8589',linewidth=.6,alpha=.32)
    body=np.array([0.,0.,float(height)])
    fwd=np.array([1.,0.,0.])
    for index in range(1,legs+1):
        angle=2*math.pi*(index-1)/legs+math.pi/5
        outward=np.array([math.cos(angle),math.sin(angle),0.])
        shoulder=body+outward*(head[0]*.76)-np.array([0,0,head[2]*.6])
        foot=outward*radius
        foot[2]=.14*foot[0]+.08*foot[1] if tilt else 0
        knee=shoulder*.48+foot*.52+outward*(43 if kind=='pendragon' else 32)
        knee[2]=max(knee[2],foot[2]+49)
        segment(ax,shoulder,knee,width*1.3,limb)
        segment(ax,knee,foot,width*(.7 if kind=='pendragon' else .85),limb)
        ellipsoid(ax,knee,[width*1.4]*3,shell,12)
        if kind!='walker':segment(ax,foot+outward*8,foot-outward*12,width*1.2,shell)
    ellipsoid(ax,body,head,shell)
    if kind=='pendragon':
        ellipsoid(ax,body+fwd*23+[0,0,13],(22,19,21),(100,110,87))
        for s in (-1,1):segment(ax,body+[0,s*32,0],body+[0,s*54,-32],4,limb)
    elif kind=='walker':
        ellipsoid(ax,body-[0,0,16],(67,61,9),limb)
    elif kind=='bbc2019':
        ellipsoid(ax,body-[0,0,17],(58,51,13),(30,42,57))
    else:
        for i in range(1,6):
            segment(ax,body+[0,(i-3)*11,0],body+[0,(i-3)*14,38+i*7],3,limb)
    eye_center=body+fwd*(head[0]*.87)+[0,0,0 if kind=='walker' else 7]
    ellipsoid(ax,eye_center,(4,12 if kind=='bbc2019' else 8,12 if kind=='bbc2019' else 8),eye,12)
    ax.scatter([eye_center[0]+5],[eye_center[1]],[eye_center[2]],s=30 if kind=='bbc2019' else 18,c=[rgb(eye)],depthshade=False)
    ax.set_xlim(-165,165);ax.set_ylim(-165,165);ax.set_zlim(-15,330)
    ax.set_box_aspect((330,330,345),zoom=1.22)
    ax.view_init(elev=19,azim=-35)
    ax.set_proj_type('persp',focal_length=.85)
    ax.set_axis_off()
    fig.text(.5,.94,title,color='white',ha='center',fontsize=18,weight='bold')
    fig.text(.5,.025,'OFFLINE GEOMETRY MOCKUP  |  NOT A GMOD SCREENSHOT',color='#b9c5cb',ha='center',fontsize=8)
    path=OUT/f'{kind}.png'
    fig.savefig(path,dpi=130,facecolor=bg)
    plt.close(fig)
    print(path.relative_to(ROOT))

for name in STYLES:render(name)

# An index image is for browsing the separate renders; it is NOT an in-game shot.
thumbs=[]
for name in STYLES:
    image=Image.open(OUT/f'{name}.png').convert('RGB')
    thumbs.append(image.resize((500,500),Image.Resampling.LANCZOS))
page=Image.new('RGB',(1000,1000),'#141c22')
for i,im in enumerate(thumbs):page.paste(im,((i%2)*500,(i//2)*500))
page.save(OUT/'overview.png',optimize=True)
print((OUT/'overview.png').relative_to(ROOT))
