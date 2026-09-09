from pathlib import Path

path = Path("WolFoxMaster.mm")
text = path.read_text(encoding="utf-8")

# Ensure the custom identifier section is explicitly exposed in the UI.
required_ui = [
    '@"المعرّف المخصص للتطبيق"',
    '@"إضافة المعرّف المخصص وتفعيله"',
    'tf.text = [WolFoxProStore shared].activeIdentifierUUID ?: @"";',
]
for marker in required_ui:
    if marker not in text:
        raise SystemExit(f"Missing required custom identifier UI marker: {marker}")

old_status = '''    UILabel *idStatus = [[UILabel alloc] initWithFrame:CGRectMake(15, 440, idCard.bounds.size.width - 30, 28)];
    BOOL identifierActive = [WolFoxProStore shared].validatedActiveIdentifier != nil;
    idStatus.text = identifierActive ? [NSString stringWithFormat:@"المعرّف المخصص مفعّل ✓  %@", [WolFoxProStore shared].activeIdentifierUUID ?: @""] : @"لا يوجد معرّف مخصص مفعّل";
    idStatus.textColor = identifierActive ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];
    idStatus.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.10];
    idStatus.layer.cornerRadius = 10; idStatus.clipsToBounds = YES;
    idStatus.font = [WolFoxProTheme fontOfSize:12 weight:UIFontWeightBold];
    idStatus.textAlignment = NSTextAlignmentCenter;
'''
new_status = '''    UILabel *idStatus = [[UILabel alloc] initWithFrame:CGRectMake(15, 436, idCard.bounds.size.width - 30, 44)];
    BOOL identifierActive = [WolFoxProStore shared].validatedActiveIdentifier != nil;
    NSString *activeIdentifierText = [WolFoxProStore shared].activeIdentifierUUID ?: @"";
    idStatus.text = identifierActive ? [NSString stringWithFormat:@"المعرّف المخصص مفعّل ✓\\n%@", activeIdentifierText] : @"لا يوجد معرّف مخصص مفعّل";
    idStatus.textColor = identifierActive ? [WolFoxProTheme success] : [WolFoxProTheme textSecondary];
    idStatus.backgroundColor = [[WolFoxProTheme accent] colorWithAlphaComponent:0.10];
    idStatus.layer.cornerRadius = 10; idStatus.clipsToBounds = YES;
    idStatus.font = [WolFoxProTheme fontOfSize:10 weight:UIFontWeightBold];
    idStatus.numberOfLines = 2;
    idStatus.adjustsFontSizeToFitWidth = YES;
    idStatus.minimumScaleFactor = 0.75;
    idStatus.textAlignment = NSTextAlignmentCenter;
'''
if old_status in text:
    text = text.replace(old_status, new_status, 1)
elif 'activeIdentifierText' not in text:
    raise SystemExit("Identifier status block is neither original nor hardened")

old_save = '''    if (normalizedUUID && [store activateIdentifierString:normalizedUUID.UUIDString]) {
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
'''
new_save = '''    if (normalizedUUID && [store activateIdentifierString:normalizedUUID.UUIDString]) {
        NSString *expectedUUID = normalizedUUID.UUIDString;
        NSString *activeUUID = store.activeIdentifierUUID ?: @"";
        BOOL activeMatchesExpected = [activeUUID caseInsensitiveCompare:expectedUUID] == NSOrderedSame;
        BOOL confirmedSaved = NO;
        for (WolFoxProIdentifier *item in store.identifiers) {
            if ([item.uuid caseInsensitiveCompare:expectedUUID] == NSOrderedSame) {
                confirmedSaved = YES;
                break;
            }
        }
        if (!activeMatchesExpected || !confirmedSaved || ![store validatedActiveIdentifier]) {
            [self showToast:@"تعذر تأكيد حفظ وتفعيل المعرّف المخصص ❌"];
            return;
        }
        tf.text = activeUUID;
        [self refreshSpoofHeaderStatus];
        UILabel *status = objc_getAssociatedObject(self, "_id_status_label");
        status.text = [NSString stringWithFormat:@"تمت الإضافة والتفعيل ✓\\n%@", activeUUID];
        status.numberOfLines = 2;
        status.textColor = [WolFoxProTheme success];
        [self showToast:@"✅ تم التحقق: المعرّف محفوظ ومفعّل"];
        [self switchPage:1];
'''
if old_save in text:
    text = text.replace(old_save, new_save, 1)
elif 'activeMatchesExpected' not in text:
    raise SystemExit("Identifier save confirmation block is neither original nor hardened")

# Final verification: the UI must expose the field, and success must only be shown
# after the entered UUID is the active UUID and is present in the saved list.
required_final = [
    'activeIdentifierText',
    'activeMatchesExpected',
    '@"✅ تم التحقق: المعرّف محفوظ ومفعّل"',
    'status.numberOfLines = 2;',
    '@"المعرّف المخصص للتطبيق"',
    '@"إضافة المعرّف المخصص وتفعيله"',
]
for marker in required_final:
    if marker not in text:
        raise SystemExit(f"Missing final identifier confirmation marker: {marker}")

path.write_text(text, encoding="utf-8")
print("Custom identifier section hardened and verified")
