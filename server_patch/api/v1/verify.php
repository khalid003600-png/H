<?php
declare(strict_types=1);
require __DIR__ . '/../../config/config.php';

$input = input();
api_rate_limit('v1_verify', 120, 60);
$project = request_v1_project($input);
$code = strtoupper(trim((string)($input['license_code'] ?? $input['code'] ?? '')));
$uuid = trim((string)($input['device_uuid'] ?? $input['device_id'] ?? ''));
$token = trim((string)($input['access_token'] ?? ''));
$appVersion = trim((string)($input['app_version'] ?? ''));

enforce_project_update($project, $appVersion);
if ($code === '' || $uuid === '') {
    json_response(['success'=>false,'error_code'=>'missing_verification_data','message'=>'Missing license code or device UUID'],422);
}

$pdo = db();
try {
    $query = $pdo->prepare('SELECT l.*, lp.name AS plan_name, lp.days FROM licenses l JOIN license_plans lp ON lp.id=l.plan_id WHERE l.code=? AND l.project_id=? LIMIT 1');
    $query->execute([$code, $project['project_id']]);
    $license = $query->fetch();
    if (!$license) json_response(['success'=>false,'status'=>'invalid','error_code'=>'invalid_license','message'=>'Invalid license code'],404);

    $state = license_state($license);
    if ($state === 'deleted') json_response(['success'=>false,'status'=>'deleted','error_code'=>'license_deleted','message'=>'License was deleted'],404);
    if ($state === 'cancelled') json_response(['success'=>false,'status'=>'cancelled','error_code'=>'license_cancelled','message'=>'License is cancelled'],403);
    if ($state === 'blocked') json_response(['success'=>false,'status'=>'blocked','error_code'=>'license_blocked','message'=>'License is blocked'],403);
    if ($state === 'expired') {
        if (($license['status'] ?? '') !== 'expired') {
            $pdo->prepare("UPDATE licenses SET status='expired',updated_at=? WHERE id=?")->execute([now_sql(),$license['id']]);
        }
        json_response(['success'=>false,'status'=>'expired','error_code'=>'license_expired','message'=>'License has expired'],403);
    }
    if (empty($license['device_uuid'])) json_response(['success'=>false,'status'=>'device_not_activated','error_code'=>'device_not_activated','message'=>'License is not activated'],409);
    if (!hash_equals((string)$license['device_uuid'],$uuid)) json_response(['success'=>false,'status'=>'device_mismatch','error_code'=>'device_mismatch','message'=>'License belongs to another device'],409);
    if ($token !== '' && !verify_access_token($project,$license,$uuid,$token)) {
        json_response(['success'=>false,'status'=>'invalid_token','error_code'=>'invalid_access_token','message'=>'Invalid access token'],401);
    }

    $pdo->prepare('UPDATE devices SET app_version=?,last_ip=?,last_seen=? WHERE license_id=? AND uuid=?')
        ->execute([$appVersion ?: null,$_SERVER['REMOTE_ADDR'] ?? '',now_sql(),$license['id'],$uuid]);

    // يتحكم مدير اللوحة في هذا المفتاح من project_settings:
    // runtime_enabled = 1 للتشغيل، و0 للإيقاف. الغياب يعني التشغيل.
    $setting = $pdo->prepare('SELECT setting_value FROM project_settings WHERE project_id=? AND setting_key IN (?,?) ORDER BY setting_key=? DESC LIMIT 1');
    $setting->execute([$project['project_id'],'runtime_enabled','license_enabled','runtime_enabled']);
    $controlValue = $setting->fetchColumn();
    $enabled = $controlValue === false || !in_array(strtolower(trim((string)$controlValue)),['0','false','off','disabled','stopped'],true);

    json_response([
        'success'=>true,
        'status'=>$enabled ? 'active' : 'disabled',
        'message'=>$enabled ? ($token === '' ? 'License session recovered' : 'License verified') : 'License disabled by administrator',
        'data'=>[
            'access_token'=>issue_access_token($project,$license,$uuid),
            'license'=>license_payload($license),
            'session_recovered'=>$token === '',
            'control'=>[
                'enabled'=>$enabled,
                'source'=>'admin_panel',
                'checked_at'=>now_sql(),
            ],
        ],
    ]);
} catch (Throwable $exception) {
    error_log('WolFox verify error: '.$exception->getMessage());
    json_response(['success'=>false,'error_code'=>'server_error','message'=>'Internal server error'],500);
}
