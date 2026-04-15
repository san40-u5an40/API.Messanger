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
CALL profile_unselect(@profile_id);
CALL profile_is_archived_set(@profile_id, true);
CALL profile_is_active_set(@profile_id, false);
CALL profile_is_can_searched_set(@profile_id, false);
CALL profile_is_allow_message_for_non_subscribers_set(@profile_id, false);
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

CALL profile_subscribe_accept(7, 1);
CALL profile_subscribe_ignore(7, 1);

CALL profile_subscribe_invite_get_info_by_url('ekaterina_pm');
CALL profile_subscribe_invite_get_invited_profiles(2);

CALL profile_content_item_create(1, 'Всем хаюшки', 3, @is_valid, @error_message, @profile_content_item_id);
CALL profile_content_item_edit(@profile_content_item_id, 'Новое значение');
SELECT profile_content_item_get_profile_id(@profile_content_item_id);
CALL profile_content_item_watch(@profile_content_item_id, 2); -- Не скрывает просмотры
CALL profile_content_item_watch(@profile_content_item_id, 3); -- Скрывает просмотры
SELECT profile_content_item_get_watching_count(@profile_content_item_id);
SELECT profile_content_item_get_sharing_count(3);
CALL profile_is_hide_watch_set(2, true);

CALL profile_content_item_report(@profile_content_item_id, 13, 'Треш, угар и содомия');

CALL profile_message_send(2, 1, 'Здаров, братка!', null, @profile_message_id);
CALL profile_content_item_get_info(profile_message_get_profile_content_item_id(@profile_message_id));
SELECT profile_message_unchecked_count_from(2, 1);
CALL profile_message_check(@profile_message_id);
SELECT profile_message_get_is_checked(@profile_message_id);

CALL profile_messages_get_from(2, 1, 100, 40);
CALL profile_messages_get_last_from(2, 1);

CALL profile_message_delete(@profile_message_id);

CALL profile_publication_create(2, 'Всем привет, я тутава!', null, @profile_publication_id);
SELECT @profile_publication_id;
CALL profile_publication_delete(@profile_publication_id);

CALL profile_publication_comment_create(@profile_publication_id, 6, 'Вот это ты загнул конечно', null, @profile_publication_comment_id);
SELECT @profile_publication_comment_id;
SELECT profile_publication_get_comments_count(@profile_publication_id);
CALL profile_publication_comment_delete(@profile_publication_comment_id);
CALL profile_publication_comment_get_from(@profile_publication_id);

CALL profile_group_chat_create(10, 'Злые киски', 'Фотографии с вашими милыми питомцами', '/avatars/злые_киски_1.jpg', @profile_group_chat_id);
CALL profile_group_chat_delete(@profile_group_chat_id);

CALL profile_group_chat_member_add(30, 13, null, 'Пахан', @profile_group_chat_member_id);
SELECT @profile_group_chat_member_id;
CALL profile_group_chat_member_delete(@profile_group_chat_member_id);

CALL profile_group_chat_member_custom_title_set(@profile_group_chat_member_id, 'Почти батя');
CALL profile_group_chat_member_block(@profile_group_chat_member_id);
CALL profile_group_chat_member_set_moderator(@profile_group_chat_member_id);
CALL profile_group_chat_member_set_member(@profile_group_chat_member_id);
CALL profile_group_chat_member_transfer_ownership(@profile_group_chat_member_id);

CALL profile_group_chat_members_get_from(30);

CALL profile_group_chat_message_send(17, 30, 'Я в этом чатике, всем дрожать!', null, @profile_group_chat_message_id);
CALL profile_group_chat_message_delete(@profile_group_chat_message_id);
CALL profile_group_chat_messages_get_from(30, 100, 10);

CALL profile_publication_check(2, 3);
CALL profile_group_chat_message_check(4, 2);









