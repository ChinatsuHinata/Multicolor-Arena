"""Read the user's teaching PSDs and retain typography evidence and native seal alpha."""
import hashlib
import json
from pathlib import Path
from PIL import Image
from psd_tools import PSDImage

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/testmod-typography-v5'
TEMPLATES=Path('D:/叶子游戏/模板')


def main():
    (OUT/'components').mkdir(parents=True,exist_ok=True)
    (OUT/'.gdignore').touch()
    specs=[('教学用 天才教师上白泽慧音.psd',[54,63,70,76,77]),('符卡 四重結界.psd',[40,42,47,58])]
    profile={'templates':[],'symbol_reference':'recourse/数据库/character-fdf-ex03.jpg',
             'symbol_convention':'+1/+1/+1 → 攻防胶囊(+1/+1) 与 灵力印章(+1)；-X/-X/-X 同理。'}
    profile['comparison_references']=[]
    for reference in ['recourse/数据库/character-fdf-ex03.jpg','recourse/数据库/异画与重复/v0.13/魔神复诵「圣白莲」__character-soi-085.jpg','recourse/数据库/124.png']:
        profile['comparison_references'].append({'file':reference,'sha256':hashlib.sha256((ROOT/reference).read_bytes()).hexdigest()})
    for filename,selected in specs:
        source=TEMPLATES/filename
        psd=PSDImage.open(source); layers=list(psd.descendants()); records=[]
        for i in selected:
            layer=layers[i]
            fonts=[f['Name'].value for f in layer.resource_dict['FontSet']]
            styles=[]
            for run in layer.engine_dict['StyleRun']['RunArray']:
                d=run['StyleSheet']['StyleSheetData']
                row={key:d[key].value for key in ['FontSize','Tracking','FauxBold'] if key in d}
                row['font']=fonts[d['Font'].value];styles.append(row)
            records.append({'layer':i,'text':layer.text,'styles':styles})
        profile['templates'].append({'path':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                                     'canvas':list(psd.size),'text_layers':records})
        if filename.startswith('教学'):
            seal=layers[79].composite(force=True).convert('RGBA')
            # Native PSD seal geometry; recolor its alpha green-to-gold as on Byakuren.
            w,h=seal.size;paint=Image.new('RGBA',(w,h)); pixels=paint.load()
            top=(65,166,112);bottom=(180,151,63)
            for y in range(h):
                t=y/max(1,h-1);color=tuple(round(a+(b-a)*t) for a,b in zip(top,bottom))
                for x in range(w):pixels[x,y]=(*color,255)
            paint.putalpha(seal.getchannel('A'));paint.save(OUT/'components/modifier-spirit.png')
            layers[76].topil().save(OUT/'components/native-unit-title-sample.png')
    assert profile['templates'][0]['text_layers'][3]['styles'][0]['font']=='SlideTownsoul-Regular'
    assert profile['templates'][1]['text_layers'][0]['styles'][0]['FontSize']==100
    (OUT/'font-profile.json').write_text(json.dumps(profile,ensure_ascii=False,indent=2),encoding='utf8')
    snapshot=OUT/'source-rules.sha256.json'
    if not snapshot.exists():
        pack=ROOT/'examples/testmod'
        manifest=json.loads((pack/'manifest.json').read_text(encoding='utf8'))
        files=[*manifest['cards'],'abilities.gd']
        snapshot.write_text(json.dumps({name:hashlib.sha256((pack/name).read_bytes()).hexdigest() for name in files},indent=2),encoding='utf8')
    print('Audited two user PSDs; extracted native spirit-seal geometry.')


if __name__=='__main__':main()
