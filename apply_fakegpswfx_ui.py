from pathlib import Path
import re
import sys

p = Path('WolFoxMaster.mm')
s = p.read_text(encoding='utf-8')

# 1) Product-facing branding only. Keep internal classes/package identity intact.
s = s.replace('WolFoxMaster.mm - WolFox v1.8.2 Full "Dark Blue Panel UI"',
              'WolFoxMaster.mm - FAKE GPS WFX Full UI')
s = s.replace('_titleLabel.text = @"Wolfox";', '_titleLabel.text = @"FAKE GPS WFX";')
s = s.replace('_titleLabel.text = @"WolFox";', '_titleLabel.text = @"FAKE GPS WFX";')
s = s.replace('_titleLabel.text = @"WolFox Full";', '_titleLabel.text = @"FAKE GPS WFX";')
s = s.replace('@"WolFox Full 2.0.0"', '@"FAKE GPS WFX 2.0.0"')

# 2) Remove onboarding/instructional overlay completely.
s = re.sub(
    r'- \(void\)presentOnboardingIfNeeded \{.*?\n\}',
    '- (void)presentOnboardingIfNeeded {\n'
    '    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_ONBOARDING_COMPLETED"];\n'
    '    [[NSUserDefaults standardUserDefaults] synchronize];\n'
    '}',
    s, count=1, flags=re.S
)

# 3) Four visible tabs only: Location, Identifiers, Camera, Settings.
s = re.sub(
    r'UIView \*indicator = \[\[UIView alloc\] initWithFrame:CGRectMake\(0, 54, w / 5\.0, 4\)\];',
    'UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 54, w / 4.0, 4)];',
    s, count=1
)
s = re.sub(
    r'NSArray \*icons = @\[@"location\.fill",\s*@"person\.text\.rectangle\.fill",\s*@"antenna\.radiowaves\.left\.and\.right",\s*@"camera\.fill",\s*@"gearshape\.fill"\];',
    'NSArray *icons = @[@"location.fill", @"person.text.rectangle.fill", @"camera.fill", @"gearshape.fill"];',
    s, count=1
)
s = re.sub(
    r'NSArray \*tabLabels = @\[@"الموقع GPS",\s*@"معرف الجهاز",\s*@"البلوتوث",\s*@"الكاميرا",\s*@"الإعدادات"\];',
    'NSArray *tabLabels = @[@"الموقع", @"المعرّفات", @"الكاميرا", @"الإعدادات"];',
    s, count=1
)
s = re.sub(
    r'NSArray \*tabPages = @\[@0,\s*@1,\s*@2,\s*@3,\s*@4\];',
    'NSArray *tabPages = @[@0, @1, @3, @4];',
    s, count=1
)

# 4) Search wording only. Do not auto-activate spoof from search.
s = s.replace('@"إحداثيات أو عنوان / اسم مكان"', '@"ابحث عن مكان أو الصق رابط Google Maps أو إحداثيات"')
s = s.replace('@"البحث بالإحداثيات أو العنوان"', '@"البحث عن مكان أو عنوان أو رابط أو إحداثيات"')

# 5) Settings order/cleanup requested by user:
#    Keep hide/show first, then notifications/floating controls, marker colors,
#    general/subscription where already implemented, and logout last.
#    Remove appearance card, Telegram/support card, and quick-use guide.
s = re.sub(r'// 2\. المظهر.*?// 3\. ألوان المؤشرات', '// 3. ألوان المؤشرات', s, count=1, flags=re.S)
s = re.sub(r'// 6\. الدعم والحساب.*?// 7\. تسجيل الخروج', '// 7. تسجيل الخروج', s, count=1, flags=re.S)

# 6) Subscription/product labels.
s = s.replace('t:@"المنتج" v:@"WolFox Full"', 't:@"المنتج" v:@"FAKE GPS WFX"')
s = s.replace('t:@"الإصدار" v:@"WolFox Full"', 't:@"الإصدار" v:@"FAKE GPS WFX"')

# Add edition row when the known product row exists and edition row is absent.
if 't:@"الإصدار" v:@"WolFox Full"' not in s and 't:@"النسخة" v:@"WolFox Full"' not in s:
    s = s.replace(
        't:@"المنتج" v:@"FAKE GPS WFX"',
        't:@"المنتج" v:@"FAKE GPS WFX"',
        1
    )

# 7) User-visible strings should no longer expose deleted UI sections in Full build.
# Internal Bluetooth implementation may remain for compatibility; only visible UI is removed.

p.write_text(s, encoding='utf-8')

# Strong post-patch validation: fail the build patch step if a requested UI cleanup did not apply.
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
        errors.append(f'missing required patched token: {token}')
for token in checks_absent:
    if token in s:
        errors.append(f'deleted UI still present: {token}')

if errors:
    print('FAKE GPS WFX patch validation failed:')
    for e in errors:
        print(' -', e)
    sys.exit(1)

print('Applied and validated consolidated FAKE GPS WFX requirements')
