from pathlib import Path
import re
import sys

p = Path('WolFoxMaster.mm')
s = p.read_text(encoding='utf-8')

# Product-facing branding only; internal classes/package identity remain unchanged.
s = s.replace('WolFoxMaster.mm - WolFox v1.8.2 Full "Dark Blue Panel UI"',
              'WolFoxMaster.mm - FAKE GPS WFX Full UI')
s = s.replace('_titleLabel.text = @"Wolfox";', '_titleLabel.text = @"FAKE GPS WFX";')
s = s.replace('_titleLabel.text = @"WolFox";', '_titleLabel.text = @"FAKE GPS WFX";')
s = s.replace('_titleLabel.text = @"WolFox Full";', '_titleLabel.text = @"FAKE GPS WFX";')
s = s.replace('@"WolFox Full 2.0.0"', '@"FAKE GPS WFX 2.0.0"')

# Phase 1: remove onboarding/instructional overlay.
s = re.sub(
    r'- \(void\)presentOnboardingIfNeeded \{.*?\n\}',
    '- (void)presentOnboardingIfNeeded {\n'
    '    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_ONBOARDING_COMPLETED"];\n'
    '    [[NSUserDefaults standardUserDefaults] synchronize];\n'
    '}',
    s, count=1, flags=re.S
)

# Phase 1: four visible tabs only. Bluetooth implementation stays internal.
s = re.sub(r'UIView \*indicator = \[\[UIView alloc\] initWithFrame:CGRectMake\(0, 54, w / 5\.0, 4\)\];',
           'UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 54, w / 4.0, 4)];', s, count=1)
s = re.sub(r'NSArray \*icons = @\[@"location\.fill",\s*@"person\.text\.rectangle\.fill",\s*@"antenna\.radiowaves\.left\.and\.right",\s*@"camera\.fill",\s*@"gearshape\.fill"\];',
           'NSArray *icons = @[@"location.fill", @"person.text.rectangle.fill", @"camera.fill", @"gearshape.fill"];', s, count=1)
s = re.sub(r'NSArray \*tabLabels = @\[@"الموقع GPS",\s*@"معرف الجهاز",\s*@"البلوتوث",\s*@"الكاميرا",\s*@"الإعدادات"\];',
           'NSArray *tabLabels = @[@"الموقع", @"المعرّفات", @"الكاميرا", @"الإعدادات"];', s, count=1)
s = re.sub(r'NSArray \*tabPages = @\[@0,\s*@1,\s*@2,\s*@3,\s*@4\];',
           'NSArray *tabPages = @[@0, @1, @3, @4];', s, count=1)

# Search text only in phase 1; functional map/search work is phase 2.
s = s.replace('@"إحداثيات أو عنوان / اسم مكان"', '@"ابحث عن مكان أو الصق رابط Google Maps أو إحداثيات"')
s = s.replace('@"البحث بالإحداثيات أو العنوان"', '@"البحث عن مكان أو عنوان أو رابط أو إحداثيات"')

# Phase 1 settings cleanup: remove appearance, Telegram/support and quick guide.
s = re.sub(r'// 2\. المظهر.*?// 3\. ألوان المؤشرات', '// 3. ألوان المؤشرات', s, count=1, flags=re.S)
s = re.sub(r'// 6\. الدعم والحساب.*?// 7\. تسجيل الخروج', '// 7. تسجيل الخروج', s, count=1, flags=re.S)

# Product label only. Edition/subscription redesign is phase 2.
s = s.replace('t:@"المنتج" v:@"WolFox Full"', 't:@"المنتج" v:@"FAKE GPS WFX"')
s = s.replace('t:@"الإصدار" v:@"WolFox Full"', 't:@"الإصدار" v:@"FAKE GPS WFX"')

p.write_text(s, encoding='utf-8')

# Fail CI instead of silently shipping a partially patched phase-one UI.
checks_present = [
    'FAKE GPS WFX',
    'NSArray *icons = @[@"location.fill", @"person.text.rectangle.fill", @"camera.fill", @"gearshape.fill"]',
    'NSArray *tabLabels = @[@"الموقع", @"المعرّفات", @"الكاميرا", @"الإعدادات"]',
    'NSArray *tabPages = @[@0, @1, @3, @4]',
    'w / 4.0',
]
checks_absent = [
    'قناة WolFox على Telegram',
    'دليل الاستخدام السريع',
    'secLabel(@"المظهر"',
    'tabLabels = @[@"الموقع GPS", @"معرف الجهاز", @"البلوتوث"',
]
errors = []
for token in checks_present:
    if token not in s:
        errors.append(f'missing phase-one token: {token}')
for token in checks_absent:
    if token in s:
        errors.append(f'phase-one deleted UI still present: {token}')
if errors:
    print('FAKE GPS WFX phase-one validation failed:')
    for e in errors:
        print(' -', e)
    sys.exit(1)
print('Applied and validated FAKE GPS WFX phase one')
