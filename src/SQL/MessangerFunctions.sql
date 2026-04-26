DELIMITER //

CREATE FUNCTION account_is_exists_by_phone(pr_phone VARCHAR(17))
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS (
		SELECT 1
        FROM account
        WHERE phone = pr_phone
    );
END //

CREATE FUNCTION account_is_exists_by_id(pr_account_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS (
		SELECT 1
        FROM account
        WHERE account_id = pr_account_id
    );
END //

CREATE FUNCTION account_get_id(pr_phone VARCHAR(17))
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT account_id
        FROM account
        WHERE phone = pr_phone
    );
END //

CREATE FUNCTION account_get_report_count(pr_account_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile_content_item_report
        WHERE account_id = pr_account_id
    );
END //

CREATE FUNCTION account_login_get_id(
	pr_account_id BIGINT UNSIGNED,
    pr_client_name VARCHAR(100)
)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
    RETURN(
		SELECT account_login_id
		FROM account_login
		WHERE
			account_id = pr_account_id AND
			client_name = CAST(pr_client_name AS BINARY)
    );
END //

CREATE FUNCTION account_login_is_exists(pr_account_login_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM account_login
        WHERE account_login_id = pr_account_login_id
    );
END //

CREATE FUNCTION account_profile_count(pr_account_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile
        WHERE account_id = pr_account_id
    );
END//

CREATE FUNCTION profile_is_exists(pr_profile_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS (
		SELECT 1
        FROM profile
        WHERE profile_id = pr_profile_id
    );
END//

CREATE FUNCTION profile_get_account_id(pr_profile_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT account_id
        FROM profile
        WHERE profile_id = pr_profile_id
    );
END//

CREATE FUNCTION profile_get_is_last_selected(pr_profile_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT is_last_selected
        FROM profile
        WHERE profile_id = pr_profile_id
    );
END//

CREATE FUNCTION profile_subscribe_invite_is_exists_by_url(pr_profile_subscribe_invite_url VARCHAR(25))
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_subscribe_invite
        WHERE url_value = pr_profile_subscribe_invite_url
    );
END//

CREATE FUNCTION profile_subscribe_invite_is_exists_by_id(pr_profile_subscribe_invite_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_subscribe_invite
        WHERE profile_subscribe_invite_id = pr_profile_subscribe_invite_id
    );
END//

CREATE FUNCTION profile_subscribe_invite_get_is_auto_accept(pr_profile_subscribe_invite_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT is_auto_accept
        FROM profile_subscribe_invite
        WHERE profile_subscribe_invite_id = pr_profile_subscribe_invite_id
    );
END//

CREATE FUNCTION profile_subscribe_invite_get_profile_id(pr_profile_subscribe_invite_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_id
        FROM profile_subscribe_invite
        WHERE profile_subscribe_invite_id = pr_profile_subscribe_invite_id
    );
END//

CREATE FUNCTION profile_subscribe_is_exists(
	pr_profile_at BIGINT UNSIGNED,
    pr_profile_to BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_subscribe
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to
    );
END//

CREATE FUNCTION profile_subscribe_invite_subscribers_count(pr_profile_subscribe_invite_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile_subscribe
        WHERE profile_subscribe_invite_id = pr_profile_subscribe_invite_id
    );
END//

CREATE FUNCTION profile_subscribe_invite_get_inviting_limit(pr_profile_subscribe_invite_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT inviting_limit
        FROM profile_subscribe_invite
        WHERE profile_subscribe_invite_id = pr_profile_subscribe_invite_id
    );
END//

CREATE FUNCTION public_info_is_exists(pr_public_info_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM public_info
        WHERE public_info_id = pr_public_info_id
    );
END//

CREATE FUNCTION profile_content_item_is_exists(pr_profile_content_item_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_content_item
        WHERE profile_content_item_id = pr_profile_content_item_id
    );
END//

CREATE FUNCTION profile_get_is_hide_watch(pr_profile_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT is_hide_watch
        FROM profile
        WHERE profile_id = pr_profile_id
    );
END//

CREATE FUNCTION profile_content_item_get_watching_count(pr_profile_content_item_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile_content_item_watch
        WHERE profile_content_item_id = pr_profile_content_item_id
    );
END//

CREATE FUNCTION profile_content_item_get_sharing_count(pr_profile_content_item_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile_content_item
        WHERE forwarded_id = pr_profile_content_item_id
    );
END//

CREATE FUNCTION profile_content_item_get_profile_id(pr_profile_content_item_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_id
        FROM profile_content_item
        WHERE profile_content_item_id = pr_profile_content_item_id
    );
END//

CREATE FUNCTION profile_content_item_report_is_exists(
	pr_profile_content_item_id BIGINT UNSIGNED,
	pr_reporter_account_id BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_content_item_report
        WHERE
			profile_content_item_id = pr_profile_content_item_id AND
            reporter_account_id = pr_reporter_account_id
    );
END//

CREATE FUNCTION profile_get_is_allow_message_for_non_subscribers(pr_profile_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT is_allow_message_for_non_subscribers
        FROM profile
        WHERE profile_id = pr_profile_id
    );
END//

CREATE FUNCTION profile_subscribe_is_accept(
	pr_profile_at BIGINT UNSIGNED,
    pr_profile_to BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT status = 'accept'
        FROM profile_subscribe
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to
    );
END//

CREATE FUNCTION profile_subscribe_is_ignore(
	pr_profile_at BIGINT UNSIGNED,
    pr_profile_to BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT status = 'ignore'
        FROM profile_subscribe
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to
    );
END//

CREATE FUNCTION profile_get_is_active(pr_profile_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT is_active
        FROM profile
        WHERE profile_id = pr_profile_id
    );
END//

CREATE FUNCTION profile_message_is_can_sended(
	pr_profile_at BIGINT UNSIGNED,
    pr_profile_to BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN IFNULL((
		SELECT
			profile_get_is_active(pr_profile_to) AND
			(profile_get_is_allow_message_for_non_subscribers(pr_profile_to) OR profile_subscribe_is_accept(pr_profile_at, pr_profile_to))
	), false);
END//

CREATE FUNCTION profile_message_is_exists(pr_profile_message_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_message
        WHERE profile_message_id = pr_profile_message_id
    );
END//

CREATE FUNCTION profile_message_get_profile_to(pr_profile_message_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_to
        FROM profile_message
        WHERE profile_message_id = pr_profile_message_id
    );
END//

CREATE FUNCTION profile_message_get_is_checked(pr_profile_message_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT is_checked
        FROM profile_message
        WHERE profile_message_id = pr_profile_message_id
    );
END//

CREATE FUNCTION profile_message_get_profile_content_item_id(pr_profile_message_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_content_item_id
        FROM profile_message
        WHERE profile_message_id = pr_profile_message_id
    );
END//

CREATE FUNCTION profile_content_item_get_value(pr_profile_content_item_id BIGINT UNSIGNED)
RETURNS TEXT
READS SQL DATA
BEGIN
	RETURN (
		SELECT value
        FROM profile_content_item
        WHERE profile_content_item_id = pr_profile_content_item_id
    );
END//

CREATE FUNCTION profile_publication_get_profile_content_item_id(pr_profile_publication_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_content_item_id
        FROM profile_publication
        WHERE profile_publication_id = pr_profile_publication_id
    );
END//

CREATE FUNCTION profile_group_chat_message_get_profile_content_item_id(pr_profile_group_chat_message_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_content_item_id
        FROM profile_group_chat_message
        WHERE profile_group_chat_message_id = pr_profile_group_chat_message_id
    );
END//

CREATE FUNCTION profile_publication_comment_get_profile_content_item_id(pr_profile_publication_comment_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_content_item_id
        FROM profile_publication_comment
        WHERE profile_publication_comment_id = pr_profile_publication_comment_id
    );
END//

CREATE FUNCTION account_get_selected_profile_count(pr_account_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile
        WHERE
			account_id = pr_account_id AND
            is_last_selected = true
    );
END//

CREATE FUNCTION account_get_selected_profile_id(pr_account_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_id
        FROM profile
        WHERE
			account_id = pr_account_id AND
            is_last_selected = true
		LIMIT 1
    );
END//

CREATE FUNCTION profile_publication_get_comments_count(pr_profile_publication_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile_publication_comment
        WHERE profile_publication_id = pr_profile_publication_id
    );
END//

CREATE FUNCTION profile_publication_is_exists(pr_profile_publication_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_publication
        WHERE profile_publication_id = pr_profile_publication_id
    );
END//

CREATE FUNCTION profile_publication_comment_is_exists(pr_profile_publication_comment_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_publication_comment
        WHERE profile_publication_comment_id = pr_profile_publication_comment_id
    );
END//

CREATE FUNCTION profile_group_chat_is_exists(pr_profile_group_chat_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_group_chat
        WHERE profile_group_chat_id = pr_profile_group_chat_id
    );
END//

CREATE FUNCTION profile_group_chat_member_get_profile_id(pr_profile_group_chat_member_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_id
        FROM profile_group_chat_member
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id
    );
END//

CREATE FUNCTION profile_group_chat_member_is_can_moderating(pr_profile_group_chat_member_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT status = 'owner' OR status = 'moderator'
        FROM profile_group_chat_member
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id
    );
END//

CREATE FUNCTION profile_group_chat_member_is_owner(pr_profile_group_chat_member_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN (
		SELECT status = 'owner'
        FROM profile_group_chat_member
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id
    );
END//

CREATE FUNCTION profile_group_chat_member_is_exists_by_info(
	pr_profile_group_chat_id BIGINT UNSIGNED,
    pr_profile_id BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_group_chat_member
        WHERE
			profile_group_chat_id = pr_profile_group_chat_id AND
			profile_id = pr_profile_id
    );
END//

CREATE FUNCTION profile_group_chat_member_is_exists_by_id(pr_profile_group_chat_member_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_group_chat_member
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id
    );
END//

CREATE FUNCTION profile_group_chat_member_get_profile_group_chat_id(pr_profile_group_chat_member_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_group_chat_id
        FROM profile_group_chat_member
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id
    );
END//

CREATE FUNCTION profile_group_chat_message_is_exists(pr_profile_group_chat_message_id BIGINT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_group_chat_message
        WHERE profile_group_chat_message_id = pr_profile_group_chat_message_id
    );
END//

CREATE FUNCTION profile_group_chat_message_get_profile_group_chat_id(pr_profile_group_chat_message_id BIGINT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_group_chat_id
        FROM profile_group_chat_message
        WHERE profile_group_chat_message_id = pr_profile_group_chat_message_id
    );
END//

CREATE FUNCTION profile_publication_checked_is_exists(
	pr_profile_at BIGINT UNSIGNED,
    pr_profile_to BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_publication_checked
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to
    );
END//

CREATE FUNCTION profile_group_chat_message_checked_is_exists(
	pr_profile_id BIGINT UNSIGNED,
    pr_profile_group_chat_id BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	RETURN EXISTS(
		SELECT 1
        FROM profile_group_chat_message_checked
        WHERE
			profile_id = pr_profile_id AND
            profile_group_chat_id = pr_profile_group_chat_id
    );
END//

CREATE FUNCTION profile_group_chat_message_checked_get_group_chat_message_id(
	pr_profile_id BIGINT UNSIGNED,
	pr_profile_group_chat_id BIGINT UNSIGNED
)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_group_chat_message_id
        FROM profile_group_chat_message_checked
        WHERE
			profile_id = pr_profile_id AND
            profile_group_chat_id = pr_profile_group_chat_id
    );
END//

CREATE FUNCTION profile_publication_checked_get_profile_publication_id(
	pr_profile_at BIGINT UNSIGNED,
    pr_profile_to BIGINT UNSIGNED
)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_publication_id
        FROM profile_publication_checked
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to
    );
END//

CREATE FUNCTION profile_group_chat_message_is_checked(
	pr_profile_id BIGINT UNSIGNED,
    pr_profile_group_chat_message_id BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	DECLARE pr_profile_group_chat_id BIGINT UNSIGNED;
    SET pr_profile_group_chat_id = profile_group_chat_message_get_profile_group_chat_id(pr_profile_group_chat_message_id);

	RETURN IFNULL((
		SELECT profile_group_chat_message_id >= pr_profile_group_chat_message_id
        FROM profile_group_chat_message_checked
        WHERE
			profile_id = pr_profile_id AND
            profile_group_chat_id = pr_profile_group_chat_id
    ), false);
END//

CREATE FUNCTION profile_publication_is_checked(
	pr_profile_id BIGINT UNSIGNED,
    pr_profile_publication_id BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
	DECLARE pr_profile_to BIGINT UNSIGNED;
	SET pr_profile_to = profile_content_item_get_profile_id(profile_publication_get_profile_content_item_id(pr_profile_publication_id));

	RETURN IFNULL((
		SELECT profile_publication_id >= pr_profile_publication_id
        FROM profile_publication_checked
        WHERE
			profile_at = pr_profile_id AND
            profile_to = pr_profile_to
    ), false);
END//

CREATE FUNCTION profile_group_chat_get_new_messages_count(
    pr_profile_group_chat_id BIGINT UNSIGNED,
    pr_profile_id BIGINT UNSIGNED
)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile_group_chat_message
        WHERE
			profile_group_chat_id = pr_profile_group_chat_id AND
			profile_group_chat_message_id > IFNULL((
				SELECT profile_group_chat_message_id
                FROM profile_group_chat_message_checked
                WHERE
					profile_id = pr_profile_id AND
                    profile_group_chat_id = pr_profile_group_chat_id
            ), 0)
    );
END//

CREATE FUNCTION profile_group_chat_get_last_message_id(pr_profile_group_chat_id BIGINT UNSIGNED)
RETURNS TEXT
READS SQL DATA
BEGIN
	RETURN (
		SELECT profile_group_chat_message_id
        FROM profile_group_chat_message
        WHERE profile_group_chat_id = pr_profile_group_chat_id
        ORDER BY profile_group_chat_message_id DESC
        LIMIT 1
    );
END//

CREATE FUNCTION profile_get_new_publications_count(
	pr_profile_at BIGINT UNSIGNED,
	pr_profile_to BIGINT UNSIGNED
)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM
			profile_publication
            INNER JOIN profile_content_item USING(profile_content_item_id)
        WHERE
			profile_id = pr_profile_to AND
			profile_publication_id > IFNULL((
				SELECT profile_publication_id
                FROM profile_publication_checked
                WHERE
					profile_at = pr_profile_at AND
                    profile_to = pr_profile_to
            ), 0)
    );
END//

CREATE FUNCTION profile_content_item_get_created_at(pr_profile_content_item_id BIGINT UNSIGNED)
RETURNS DATETIME
READS SQL DATA
BEGIN
	RETURN (
		SELECT created_at
        FROM profile_content_item
        WHERE profile_content_item_id = pr_profile_content_item_id
    );
END//

CREATE FUNCTION profile_group_chat_member_get_count(pr_profile_group_chat_id BIGINT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
	RETURN (
		SELECT COUNT(*)
        FROM profile_group_chat_member
        WHERE profile_group_chat_id = pr_profile_group_chat_id
    );
END//

DELIMITER ;