from pathlib import Path

path = Path("WolFoxMaster.mm")
text = path.read_text(encoding="utf-8")

replacements = [
    (
        'NSArray *tabLabels = @[@"الموقع GPS", @"معرف الجهاز", @"البلوتوث", @"الكاميرا", @"الإعدادات"];',
        'NSArray *tabLabels = @[@"الموقع GPS", @"المعرّف المخصص", @"البلوتوث", @"الكاميرا", @"الإعدادات"];',
    ),
    (
        'title.text = @"الهوية الموحدة • IDFA • IDFV • Web";',
        'title.text = @"المعرّف المخصص للتطبيق";',
    ),
    (
        'tf.placeholder = @"أدخل UUID هنا — مثال: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";',
        'tf.placeholder = @"UUID مخصص — XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";',
    ),
    (
        '    tf.clearButtonMode = UITextFieldViewModeWhileEditing;\n    tf.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];',
        '    tf.clearButtonMode = UITextFieldViewModeWhileEditing;\n    tf.returnKeyType = UIReturnKeyDone;\n    tf.accessibilityLabel = @"إدخال المعرّف المخصص UUID";\n    tf.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];',
    ),
    (
        'UIButton *sav = [self royalBtnInside:idCard t:@"إضافة المعرف وتفعيله" i:@"checkmark" c:[WolFoxProTheme success] y:185];',
        'UIButton *sav = [self royalBtnInside:idCard t:@"إضافة المعرّف المخصص وتفعيله" i:@"checkmark" c:[WolFoxProTheme success] y:185];',
    ),
    (
        'idStatus.text = identifierActive ? @"حالة تزييف المعرّفات: مفعّل" : @"حالة تزييف المعرّفات: متوقف";',
        'idStatus.text = identifierActive ? [NSString stringWithFormat:@"المعرّف المخصص مفعّل ✓  %@", [WolFoxProStore shared].activeIdentifierUUID ?: @""] : @"لا يوجد معرّف مخصص مفعّل";',
    ),
]

for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one occurrence, found {count}: {old[:80]}")
    text = text.replace(old, new, 1)

old_save = '''- (void)saveIDProPage {
    UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
    if ([[WolFoxProStore shared] activateIdentifierString:tf.text ?: @""]) {
        tf.text = [WolFoxProStore shared].activeIdentifierUUID;
        [self refreshSpoofHeaderStatus];
        [self showToast:@"✅ تمت إضافة المعرّف وتفعيله"];
        UILabel *status = objc_getAssociatedObject(self, "_id_status_label");
        status.text = @"حالة تزييف المعرّفات: مفعّل";
        status.textColor = [WolFoxProTheme success];
    } else {
        [self showToast:@"صيغة UUID غير صحيحة ❌"];
    }
}
'''

new_save = '''- (void)saveIDProPage {
    UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
    WolFoxProStore *store = [WolFoxProStore shared];
    if ([store activateIdentifierString:tf.text ?: @""]) {
        NSString *activeUUID = store.activeIdentifierUUID ?: @"";
        BOOL confirmedSaved = NO;
        for (WolFoxProIdentifier *item in store.identifiers) {
            if ([item.uuid caseInsensitiveCompare:activeUUID] == NSOrderedSame) {
                confirmedSaved = YES;
                break;
            }
        }
        if (!confirmedSaved || ![store validatedActiveIdentifier]) {
            [self showToast:@"تعذر تأكيد حفظ المعرّف المخصص ❌"];
            return;
        }
        tf.text = activeUUID;
        [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_id_status_label");
        status.text = [NSString stringWithFormat:@"تمت الإضافة والتفعيل ✓  %@", activeUUID];
        status.textColor = [WolFoxProTheme success];
        [self showToast:@"✅ تم حفظ المعرّف المخصص وتفعيله"];
        [self switchPage:1];
    } else {
        [self showToast:@"صيغة UUID غير صحيحة ❌"];
    }
}
'''

if text.count(old_save) != 1:
    raise SystemExit("saveIDProPage block did not match exactly once")
text = text.replace(old_save, new_save, 1)

old_notification = '        status.text = active ? @"حالة تزييف المعرّفات: مفعّل" : @"حالة تزييف المعرّفات: متوقف";'
new_notification = '        status.text = active ? [NSString stringWithFormat:@"المعرّف المخصص مفعّل ✓  %@", [WolFoxProStore shared].activeIdentifierUUID ?: @""] : @"لا يوجد معرّف مخصص مفعّل";'
if text.count(old_notification) != 1:
    raise SystemExit("identifierStateChanged status line did not match exactly once")
text = text.replace(old_notification, new_notification, 1)

required = [
    '@"المعرّف المخصص للتطبيق"',
    '@"إضافة المعرّف المخصص وتفعيله"',
    'BOOL confirmedSaved = NO;',
    '@"✅ تم حفظ المعرّف المخصص وتفعيله"',
    'store.identifiers',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"Missing expected marker after patch: {marker}")

path.write_text(text, encoding="utf-8")
print("Custom identifier UI patch applied and verified")
