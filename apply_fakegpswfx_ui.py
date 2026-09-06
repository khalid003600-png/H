from pathlib import Path
import re
p=Path('WolFoxMaster.mm')
s=p.read_text(encoding='utf-8')

# Product-facing branding
s=s.replace('WolFoxMaster.mm - WolFox v1.8.2 Full "Dark Blue Panel UI"','WolFoxMaster.mm - FAKE GPS WFX Full UI')
s=s.replace('_titleLabel.text = @"Wolfox";', '_titleLabel.text = @"FAKE GPS WFX";')
s=s.replace('_titleLabel.text = @"WolFox";', '_titleLabel.text = @"FAKE GPS WFX";')
s=s.replace('_titleLabel.text = @"WolFox Full";', '_titleLabel.text = @"FAKE GPS WFX";')
s=s.replace('@"مرحباً بك في WolFox Full"', '@"FAKE GPS WFX"')

# Disable onboarding/instructional overlay completely
s=re.sub(r'- \(void\)presentOnboardingIfNeeded \{.*?\n\}', '- (void)presentOnboardingIfNeeded {\n    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_ONBOARDING_COMPLETED"];\n}', s, count=1, flags=re.S)

# Four visible tabs: Location, Identifiers, Camera, Settings. Bluetooth UI removed.
s=re.sub(r'UIView \*indicator = \[\[UIView alloc\] initWithFrame:CGRectMake\(0, 54, w / 5\.0, 4\)\];', 'UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 54, w / 4.0, 4)];', s, count=1)
s=re.sub(r'NSArray \*icons = @\[@"location\.fill",\s*@"person\.text\.rectangle\.fill",\s*@"antenna\.radiowaves\.left\.and\.right",\s*@"camera\.fill",\s*@"gearshape\.fill"\];', 'NSArray *icons = @[@"location.fill", @"person.text.rectangle.fill", @"camera.fill", @"gearshape.fill"];', s, count=1)
s=re.sub(r'NSArray \*tabLabels = @\[@"الموقع GPS",\s*@"معرف الجهاز",\s*@"البلوتوث",\s*@"الكاميرا",\s*@"الإعدادات"\];', 'NSArray *tabLabels = @[@"الموقع", @"المعرّفات", @"الكاميرا", @"الإعدادات"];', s, count=1)
s=re.sub(r'NSArray \*tabPages = @\[@0,\s*@1,\s*@2,\s*@3,\s*@4\];', 'NSArray *tabPages = @[@0, @1, @3, @4];', s, count=1)

# Search wording
s=s.replace('@"إحداثيات أو عنوان / اسم مكان"', '@"بحث عن موقع أو لصق رابط/إحداثيات"')
s=s.replace('@"البحث بالإحداثيات أو العنوان"', '@"البحث عن مكان أو عنوان أو رابط أو إحداثيات"')

# Remove appearance section marked for deletion
s=re.sub(r'// 2\. المظهر.*?// 3\. ألوان المؤشرات', '// 3. ألوان المؤشرات', s, count=1, flags=re.S)

# Remove Telegram/support + quick guide completely, keep logout
s=re.sub(r'// 6\. الدعم والحساب.*?// 7\. تسجيل الخروج', '// 7. تسجيل الخروج', s, count=1, flags=re.S)

# Subscription product-facing labels where present
s=s.replace('t:@"المنتج" v:@"WolFox Full"', 't:@"المنتج" v:@"FAKE GPS WFX"')
s=s.replace('t:@"الإصدار" v:@"WolFox Full"', 't:@"الإصدار" v:@"FAKE GPS WFX"')
s=s.replace('@"WolFox Full 2.0.0"', '@"FAKE GPS WFX 2.0.0"')

p.write_text(s,encoding='utf-8')
print('Applied remaining FAKE GPS WFX UI cleanup')
