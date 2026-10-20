"""Create a local review sheet anchored to the original Byakuren card."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/testmod-typography-v5'
FONT='C:/Windows/Fonts/msyh.ttc'


def main():
    sheet=Image.new('RGB',(1800,1670),'#17202b')
    draw=ImageDraw.Draw(sheet)
    font=ImageFont.truetype(FONT,25);small=ImageFont.truetype(FONT,21)
    def label(x,y,s):draw.text((x,y),s,font=font,fill='white')
    def fit(image,x,y,w,h):
        image=image.convert('RGBA');scale=min(w/image.width,h/image.height)
        image=image.resize((max(1,round(image.width*scale)),max(1,round(image.height*scale))),Image.Resampling.LANCZOS)
        sheet.paste(image,(x+(w-image.width)//2,y+(h-image.height)//2),image)
    original=Image.open(ROOT/'recourse/数据库/character-fdf-ex03.jpg')
    old=Image.open(ROOT/'output/testmod-typography-v4/cards/byakuren.png')
    new=Image.open(OUT/'cards/byakuren.png')
    spell=Image.open(OUT/'cards/recitation.png')
    label(25,18,'原版圣白莲（FDF-EX03）');fit(original,25,65,445,625)
    label(495,18,'testmod 圣白莲 · v5');fit(new,495,65,445,625)
    label(970,18,'大魔法「魔神复诵」· v5');fit(spell,970,65,800,625)
    label(25,715,'标题：原版 / v4 / v5（演示镇魂行楷；符卡使用華康金文體）')
    def title_box(revision):
        records=json.loads((ROOT/'output'/revision/'layers/byakuren/text-layers.json').read_text(encoding='utf8'))
        r=next(r for r in records if r['attrs'].get('data-role')=='title')
        return (r['left']-4,r['top']-4,r['left']+r['width']+4,r['top']+r['height']+4)
    for y,image,box,caption in [(765,original,(230,62,579,128),'原版圣白莲'),
                               (865,old,title_box('testmod-typography-v4'),'v4'),
                               (965,new,title_box('testmod-typography-v5'),'v5：按教学 PSD 字体与标题外缘校准')]:
        draw.text((30,y+25),caption,font=small,fill='white');fit(image.crop(box),590,y,1140,90)
    label(25,1080,'属性符号（按卡面实际方向显示）')
    for x,caption in [(30,'原版圣白莲：横排'),(620,'v5 上升：竖排，“与”保持直立'),(1210,'v5 下降：横排')]:
        draw.text((x,1130),caption,font=small,fill='white')
    fit(original.crop((416,852,592,904)),30,1175,500,350)
    for x,identifier in [(620,'recitation'),(1210,'utsuho')]:
        folder=OUT/'layers'/identifier
        symbol=json.loads((folder/'symbols.json').read_text(encoding='utf8'))[0]
        box=Image.open(folder/symbol['file']).getbbox()
        crop=Image.open(OUT/'cards'/f'{identifier}.png').crop((box[0]-5,box[1]-5,box[2]+5,box[3]+5))
        fit(crop,x,1175,530,350)
    draw.text((30,1560),'牌文保持源 JSON 语义；三维变化显示为攻防胶囊与灵力印章。',font=font,fill='#c7d8e7')
    draw.text((30,1605),'PSD 保留可编辑文字与独立属性符号组；本机未做 Photoshop 内重排测试。',font=small,fill='#c7d8e7')
    sheet.save(OUT/'reference-comparison.png')
    gallery=OUT/'comparison-gallery.html'
    html=gallery.read_text(encoding='utf8')
    html=html.replace('<h1>testmod · 正确模板重制逐张对照</h1>',
        '<h1>testmod · 教学 PSD 与原版圣白莲对照修订 v5</h1><p><a href="使用说明.txt">说明</a> · <a href="font-profile.json">模板字体证据</a></p><img src="reference-comparison.png" alt="原版圣白莲、修订卡图、标题与属性符号对照">')
    html=html.replace('原尺寸 PNG</a>','原尺寸 PNG</a>')
    for card in json.loads((OUT/'render-report.json').read_text(encoding='utf8')):
        identifier=card['id']
        html=html.replace(f'cards/{identifier}.png">原尺寸 PNG</a>',f'cards/{identifier}.png">原尺寸 PNG</a> · <a href="psd/{identifier}.psd">分层 PSD</a>')
    gallery.write_text(html,encoding='utf8')
    print('Created original Byakuren / v4 / v5 review sheet and gallery.')


if __name__=='__main__':main()
