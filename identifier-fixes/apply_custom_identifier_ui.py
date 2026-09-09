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
        '    tf.text = [WolFoxProStore shared].activeIdentifierUUID ?: [WFLicenseClient deviceIdentifier];\n    tf.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];',
        '    tf.placeholder = @"UUID مخصص — XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";\n    tf.text = [WolFoxProStore shared].activeIdentifierUUID ?: @"";\n    tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;\n    tf.autocorrectionType = UITextAutocorrectionTypeNo;\n    tf.clearButtonMode = UITextFieldViewModeWhileEditing;\n    tf.returnKeyType = UIReturnKeyDone;\n    tf.accessibilityLabel = @"إدخال المعرّف المخصص UUID";\n    tf.font = [WolFoxProTheme fontOfSize:11 weight:UIFontWeightBold];',
    ),
    (
        'UIButton *sav = [self royalBtnInside:idCard t:@"حفظ وتفعيل" i:@"checkmark" c:[WolFoxProTheme success] y:185];',
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
        raise SystemExit(f"Expected exactly one occurrence, found {count}: {old[:100]}")
    text = text.replace(old, new, 1)

old_save = '''- (void)saveIDProPage {
    UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
    NSString *raw = [tf.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    raw = [raw stringByReplacingOccurrencesOfString:@"urn:uuid:" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, raw.length)];
    raw = [raw stringByReplacingOccurrencesOfString:@"{" withString:@""];
    raw = [raw stringByReplacingOccurrencesOfString:@"}" withString:@""];
    NSUUID *normalizedUUID = [[NSUUID alloc] initWithUUIDString:raw];
    if (normalizedUUID && [[WolFoxProStore shared] activateIdentifierString:normalizedUUID.UUIDString]) {
        tf.text = [WolFoxProStore shared].activeIdentifierUUID;
        [self refreshSpoofHeaderStatus];
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
    NSString *raw = [tf.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    if ([raw.lowercaseString hasPrefix:@"urn:uuid:"]) raw = [raw substringFromIndex:9];
    if ([raw hasPrefix:@"{"] && [raw hasSuffix:@"}"] && raw.length > 2) {
        raw = [raw substringWithRange:NSMakeRange(1, raw.length - 2)];
    }
    NSUUID *normalizedUUID = [[NSUUID alloc] initWithUUIDString:raw];
    if (normalizedUUID && [store activateIdentifierString:normalizedUUID.UUIDString]) {
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

old_reset = '''        NSString *orig = [WFLicenseClient deviceIdentifier];
        UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
        tf.text = orig; [[WolFoxProStore shared] deactivateIdentifier]; [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_id_status_label");
        status.text = @"حالة تزييف المعرّفات: متوقف";
        status.textColor = [WolFoxProTheme textSecondary];'''
new_reset = '''        UITextField *tf = objc_getAssociatedObject(self, "_id_tf_page");
        tf.text = @"";
        [[WolFoxProStore shared] deactivateIdentifier];
        [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_id_status_label");
        status.text = @"لا يوجد معرّف مخصص مفعّل";
        status.textColor = [WolFoxProTheme textSecondary];
        [self showToast:@"✅ تم إيقاف المعرّف المخصص والعودة للأصلي"];'''
if text.count(old_reset) != 1:
    raise SystemExit("resetIDProPage block did not match exactly once")
text = text.replace(old_reset, new_reset, 1)

required = [
    '@"المعرّف المخصص للتطبيق"',
    '@"إضافة المعرّف المخصص وتفعيله"',
    'BOOL confirmedSaved = NO;',
    '@"✅ تم حفظ المعرّف المخصص وتفعيله"',
    'tf.text = [WolFoxProStore shared].activeIdentifierUUID ?: @"";',
    'store.identifiers',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"Missing expected marker after patch: {marker}")

path.write_text(text, encoding="utf-8")
print("Custom identifier UI patch applied and verified")
