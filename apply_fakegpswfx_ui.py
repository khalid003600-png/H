from pathlib import Path
import re
p=Path('WolFoxMaster.mm')
s=p.read_text(encoding='utf-8')
# Product-facing branding
s=s.replace('WolFoxMaster.mm - WolFox v1.8.2 Full "Dark Blue Panel UI"','WolFoxMaster.mm - FAKE GPS WFX Full UI')
s=s.replace('_titleLabel.text = @"Wolfox";', '_titleLabel.text = @"FAKE GPS WFX";')
s=s.replace('_titleLabel.text = @"WolFox";', '_titleLabel.text = @"FAKE GPS WFX";')
s=s.replace('@"مرحباً بك في WolFox Full"', '@"FAKE GPS WFX"')
# Disable onboarding/instructional overlay completely
s=re.sub(r'- \(void\)presentOnboardingIfNeeded \{.*?\n\}', '- (void)presentOnboardingIfNeeded {\n    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_ONBOARDING_COMPLETED"];\n}', s, count=1, flags=re.S)
# Four visible tabs: Location, Identifiers, Camera, Settings. Bluetooth implementation stays internal for compatibility.
s=re.sub(r'NSArray \*icons = @\[@"location\.fill",\s*@"person\.text\.rectangle\.fill",\s*@"antenna\.radiowaves\.left\.and\.right",\s*@"camera\.fill",\s*@"gearshape\.fill"\];', 'NSArray *icons = @[@"location.fill", @"person.text.rectangle.fill", @"camera.fill", @"gearshape.fill"];', s, count=1)
s=re.sub(r'NSArray \*tabLabels = @\[@"الموقع",\s*@"المعرّفات",\s*@"البلوتوث",\s*@"الكاميرا",\s*@"الإعدادات"\];', 'NSArray *tabLabels = @[@"الموقع", @"المعرّفات", @"الكاميرا", @"الإعدادات"];', s, count=1)
# Switch page mapping after Bluetooth tab removal
s=s.replace('else if (page == 2) [self setupBluetoothPage];\n    else if (page == 3) [self setupCameraPage];\n    else if (page == 4) [self setupSettingsPage];', 'else if (page == 2) [self setupCameraPage];\n    else if (page == 3) [self setupSettingsPage];')
s=s.replace('if (page != 3) {', 'if (page != 2) {')
# Search wording
s=s.replace('@"إحداثيات أو عنوان / اسم مكان"', '@"ابحث عن مكان أو الصق رابط Google Maps"')
s=s.replace('@"البحث بالإحداثيات أو العنوان"', '@"البحث عن مكان أو عنوان أو رابط أو إحداثيات"')
# Subscription product-facing labels where present
s=s.replace('t:@"المنتج" v:@"WolFox Full"', 't:@"المنتج" v:@"FAKE GPS WFX"')
s=s.replace('t:@"الإصدار" v:@"WolFox Full"', 't:@"الإصدار" v:@"FAKE GPS WFX"')
s=s.replace('@"WolFox Full 2.0.0"', '@"FAKE GPS WFX 2.0.0"')
p.write_text(s,encoding='utf-8')
print('Applied FAKE GPS WFX UI/build branding patch')
