CALL account_create('+7 9001234566', 'Саня', 'Мыхалыч', @new_account_id);
SELECT @new_account_id;

CALL account_delete('+7 9001234566');

CALL account_login(20, 'CentBrowser', @account_login_id);
SELECT @account_login_id;
CALL account_logout(@account_login_id);

CALL profile_create(2, null, 'Public (Санёчкинский)', 'Этот профиль не нуждается в описании', 'https://example.com/avka_dlya_sanyochka.jpeg', @profile_id);
SELECT @profile_id;
SELECT account_profile_count(2);

CALL profile_select(@profile_id);
CALL profile_is_archived_set(@profile_id, true);
CALL profile_is_active_set(@profile_id, false);
CALL profile_is_can_searched_set(@profile_id, false);
CALL account_get_profiles(2, false);

CALL profiles_search('Public', 0, 10);
CALL profile_get_info(2);

CALL profile_delete(@profile_id);

CALL public_info_name_set(2, 'Петя Петров');
CALL public_info_details_set(2, 'Просто спортсмен');
CALL public_info_avatar_url_set(2, '/avatars/petynya.jpg');

CALL profile_subscribe_invite_create(1, 'friends', true, null, null, null, @profile_subscribe_invite_id);
CALL profile_subscribe_invite_delete(@profile_subscribe_invite_id);

CALL profile_subscribe(7, 1, 2);
CALL profile_unsubscribe(7, 1);
CALL profile_get_subscribers(1, 'accept');

CALL profile_subscribe_invite_get_info_by_url('ekaterina_pm');
CALL profile_subscribe_invite_get_invited_profiles(2);






