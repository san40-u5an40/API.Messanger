DELIMITER //

CREATE PROCEDURE account_create(
	IN pr_phone VARCHAR(17),
    IN pr_first_name VARCHAR(25),
    IN pr_last_name VARCHAR(25),
    OUT pr_account_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    IF pr_phone IS NULL OR pr_first_name IS NULL OR pr_last_name IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать телефон, имя и фамилию для создания аккаунта' AS message,
            false AS is_valid;
    ELSEIF account_is_exists_by_phone(pr_phone) THEN
		ROLLBACK;
		SELECT
			'Аккаунт с указанным номером уже существует' AS message,
            false AS is_valid;
     ELSE
		INSERT INTO account
		SET
			phone = pr_phone,
			first_name = pr_first_name,
			last_name = pr_last_name;
            
		SET pr_account_id = LAST_INSERT_ID();
		
        SELECT
			'Аккаунт успешно создан' AS message,
			true AS is_valid;
		COMMIT;       
    END IF;
END//

CREATE PROCEDURE account_delete(IN pr_phone VARCHAR(17))
BEGIN
	START TRANSACTION;
    
    IF pr_phone IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать номер телефона для удаления аккаунта' AS message,
            false AS is_valid;
    ELSEIF NOT account_is_exists_by_phone(pr_phone) THEN
		ROLLBACK;
		SELECT
			'Аккаунта с указанным номером не существует' AS message,
            false AS is_valid;
    ELSE
		INSERT INTO account_deleted_history
        SET
			phone = pr_phone,
            report_count = account_get_report_count(account_get_id(pr_phone));
    
		DELETE
		FROM account
		WHERE phone = pr_phone;
		
        SELECT
			'Аккаунт успешно удалён' AS message,
			true AS is_valid;
		COMMIT;    
    END IF;
END//

CREATE PROCEDURE account_login(
	IN pr_account_id BIGINT UNSIGNED,
    IN pr_client_name VARCHAR(100),
    OUT pr_account_login_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    SET pr_account_login_id = account_login_get_id(pr_account_id, pr_client_name);
    
    IF pr_account_id IS NULL OR pr_client_name IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать аккаунт и приложение-клиент для внесения информации о сессии' AS message,
            false AS is_valid;
	ELSEIF NOT account_is_exists_by_id(pr_account_id) THEN
		ROLLBACK;
		SELECT
			'Указанного аккаунта не существует' AS message,
			false AS is_valid;
    ELSEIF pr_account_login_id IS NULL THEN
		INSERT INTO account_login
		SET
			account_id = pr_account_id,
			client_name = pr_client_name;
			
		SET pr_account_login_id = LAST_INSERT_ID();
			
		SELECT
			'Вход осуществлён успешно' AS message,
			true AS is_valid;
		COMMIT;
    ELSE
		UPDATE account_login
        SET last_visited_at = NOW()
		WHERE
			account_login_id = pr_account_login_id AND
            client_name = pr_client_name;
        
		SELECT
			'Данные о входе обновлены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE account_logout(IN pr_account_login_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    IF pr_account_login_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор сессии для выхода' AS message,
            false AS is_valid;    
    ELSEIF NOT account_login_is_exists(pr_account_login_id) THEN
		ROLLBACK;
		SELECT
			'Указанная информация о сессии не была найдена' AS message,
			false AS is_valid;
    ELSE
		DELETE
		FROM account_login
        WHERE account_login_id = pr_account_login_id;
        
        SELECT
			'Выход осуществлён успешно' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_create(
	IN pr_account_id BIGINT UNSIGNED,
    IN pr_account_profile_limit INT UNSIGNED,
    IN pr_name VARCHAR(40),
    IN pr_details VARCHAR(100),
    IN pr_avatar_url TEXT,
    OUT pr_profile_id BIGINT UNSIGNED
)
BEGIN
	DECLARE pr_account_profile_count INT UNSIGNED;

	START TRANSACTION;
    
    SET pr_account_profile_count = account_profile_count(pr_account_id);
    IF pr_account_id IS NULL OR pr_name IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать аккаунт и имя профиля для его создания' AS message,
            false AS is_valid;
    ELSEIF NOT account_is_exists_by_id(pr_account_id) THEN
		ROLLBACK;
		SELECT
			'Указанного аккаунта не существует' AS message,
			false AS is_valid;
    ELSEIF pr_account_profile_count >= IFNULL(pr_account_profile_limit, 10) THEN
		ROLLBACK;
		SELECT
			'Достигнут лимит создаваемых профилей' AS message,
			false AS is_valid;
    ELSE
		INSERT INTO public_info
        SET
			name = pr_name,
            details = pr_details,
            avatar_url = pr_avatar_url;
        
        SET pr_profile_id = LAST_INSERT_ID();
        
        INSERT INTO profile
        SET
			profile_id = pr_profile_id,
            account_id = pr_account_id;
            
		SELECT
			'Профиль успешно создан' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_check_valid(
	IN pr_profile_id BIGINT UNSIGNED,
    OUT pr_is_valid BOOLEAN,
    OUT pr_message TEXT
)
BEGIN
    IF pr_profile_id IS NULL THEN
		SET pr_is_valid = false;
        SET pr_message = 'Необходимо указать идентификатор профиля';
    ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		SET pr_is_valid = false;
        SET pr_message = 'Указанного профиля не существует';
	ELSE
		SET pr_is_valid = true;
        SET pr_message = null;
    END IF;
END//

CREATE PROCEDURE profile_delete(IN pr_profile_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		DELETE FROM profile
        WHERE profile_id = pr_profile_id;
    
		DELETE FROM public_info
        WHERE public_info_id = pr_profile_id;
        
		SELECT
			'Профиль успешно удалён' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_select(IN pr_profile_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile
		SET is_last_selected = (profile_id = pr_profile_id)
        WHERE
			account_id = profile_get_account_id(pr_profile_id) AND
            profile_id > 0; -- Чтобы не выключать SafeMode
        
		SELECT
			'Профиль успешно выбран' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_unselect(IN pr_profile_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF NOT profile_get_is_last_selected(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Профиль изначально не был выбран' AS message,
            false AS is_valid;
    ELSE
		UPDATE profile
		SET is_last_selected = false
        WHERE profile_id = pr_profile_id;
        
		SELECT
			'Выбор профиля успешно отменён' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_is_archived_set(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_is_archived BOOLEAN
)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile
		SET is_archived = pr_is_archived
        WHERE profile_id = pr_profile_id;
        
		SELECT
			'Настройки профиля успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_is_active_set(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_is_active BOOLEAN
)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile
		SET is_active = pr_is_active
        WHERE profile_id = pr_profile_id;
        
		SELECT
			'Настройки профиля успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_is_can_searched_set(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_is_can_searched BOOLEAN
)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile
		SET is_can_searched = pr_is_can_searched
        WHERE profile_id = pr_profile_id;
        
		SELECT
			'Настройки профиля успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_is_allow_message_for_non_subscribers_set(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_is_allow_message_for_non_subscribers BOOLEAN
)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile
		SET is_allow_message_for_non_subscribers = pr_is_allow_message_for_non_subscribers
        WHERE profile_id = pr_profile_id;
        
		SELECT
			'Настройки профиля успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_get_info(IN pr_profile_id BIGINT UNSIGNED)
BEGIN
	SELECT
		p.is_archived,
        p.is_can_searched,
        p.is_hide_watch,
        p.is_active,
        pi.created_at,
        pi.name,
        pi.details,
        pi.avatar_url
	FROM
		profile AS p
        INNER JOIN public_info AS pi ON p.profile_id = pi.public_info_id
    WHERE profile_id = pr_profile_id;
END//

CREATE PROCEDURE account_get_profiles(
	IN pr_account_id BIGINT UNSIGNED,
    IN pr_is_archived BOOLEAN
)
BEGIN
	SELECT
		profile_id,
        name,
        avatar_url,
        is_last_selected,
        is_active
	FROM
		profile
        INNER JOIN public_info ON profile_id = public_info_id
	WHERE
		account_id = pr_account_id AND
        is_archived = pr_is_archived;
END//

CREATE PROCEDURE profiles_search(
	IN pr_name VARCHAR(40),
    IN pr_profile_id_start BIGINT UNSIGNED, -- Для эффективной пагинации, но без возможности указывать конкретные страницы для перехода
    IN pr_profiles_count INT UNSIGNED
)
BEGIN
	SELECT
		profile_id,
        name,
        avatar_url
	FROM
		profile
        INNER JOIN public_info ON profile_id = public_info_id
	WHERE
		profile_id > pr_profile_id_start AND
		MATCH(name) AGAINST(pr_name) AND
        is_can_searched = true AND
        is_archived = false
	LIMIT pr_profiles_count;
END//

CREATE PROCEDURE public_info_check_valid(
	IN pr_public_info_id BIGINT UNSIGNED,
    OUT pr_is_valid BOOLEAN,
    OUT pr_message TEXT
)
BEGIN
    IF pr_public_info_id IS NULL THEN
		SET pr_is_valid = false;
        SET pr_message = 'Необходимо указать идентификатор публичной информации';
    ELSEIF NOT public_info_is_exists(pr_public_info_id) THEN
		SET pr_is_valid = false;
        SET pr_message = 'Указанной публичной информации не существует';
	ELSE
		SET pr_is_valid = true;
        SET pr_message = null;
    END IF;
END//

CREATE PROCEDURE public_info_name_set(
	IN pr_public_info_id BIGINT UNSIGNED,
    IN pr_name VARCHAR(40)
)
BEGIN
	START TRANSACTION;
    
    CALL public_info_check_valid(pr_public_info_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE public_info
		SET name = pr_name
        WHERE public_info_id = pr_public_info_id;
        
		SELECT
			'Настройки публичной информации успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE public_info_details_set(
	IN pr_public_info_id BIGINT UNSIGNED,
    IN pr_details VARCHAR(100)
)
BEGIN
	START TRANSACTION;
    
    CALL public_info_check_valid(pr_public_info_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE public_info
		SET details = pr_details
        WHERE public_info_id = pr_public_info_id;
        
		SELECT
			'Настройки публичной информации успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE public_info_avatar_url_set(
	IN pr_public_info_id BIGINT UNSIGNED,
    IN pr_avatar_url TEXT
)
BEGIN
	START TRANSACTION;
    
    CALL public_info_check_valid(pr_public_info_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE public_info
		SET avatar_url = pr_avatar_url
        WHERE public_info_id = pr_public_info_id;
        
		SELECT
			'Настройки публичной информации успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_subscribe_invite_create(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_name VARCHAR(25),
    IN pr_is_auto_accept BOOLEAN,
    IN pr_url_value VARCHAR(25),
    IN pr_inviting_limit INT UNSIGNED,
    IN pr_miniature_url TEXT,
    OUT pr_profile_subscribe_invite_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    IF pr_profile_id IS NULL OR pr_name IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор профиля и имя пригласительной ссылки' AS message,
            false AS is_valid;
    ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанного профиля не существует' AS message,
			false AS is_valid;
	ELSEIF profile_subscribe_invite_is_exists_by_url(pr_url_value) THEN
		ROLLBACK;
		SELECT
			'Пригласительная ссылка с таким значением уже существует' AS message,
			false AS is_valid;
    ELSE
		-- Генерация случайной ссылки, если она не указана
		IF pr_url_value IS NULL THEN
			while_url_exists: WHILE true DO
				SET pr_url_value = TO_BASE64(RANDOM_BYTES(15));
                
				IF NOT profile_subscribe_invite_is_exists_by_url(pr_url_value) THEN
					LEAVE while_url_exists;
				END IF;
			END WHILE while_url_exists;
        END IF;
        
        INSERT INTO profile_subscribe_invite
        SET
				profile_id = pr_profile_id,
				name = pr_name,
                is_auto_accept = IFNULL(pr_is_auto_accept, false),
				url_value = pr_url_value,
				miniature_url = pr_miniature_url,
				inviting_limit = pr_inviting_limit;
        
        SET pr_profile_subscribe_invite_id = LAST_INSERT_ID();
        
		SELECT
			'Пригласительная ссылка успешно создана' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_subscribe_invite_delete(IN pr_profile_subscribe_invite_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    IF pr_profile_subscribe_invite_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор пригласительной ссылки' AS message,
            false AS is_valid;
	ELSEIF NOT profile_subscribe_invite_is_exists_by_id(pr_profile_subscribe_invite_id) THEN
		ROLLBACK;
		SELECT
			'Пригласительная ссылка с указанным идентификатором не была найдена' AS message,
			false AS is_valid;
    ELSE
		DELETE
        FROM profile_subscribe_invite
        WHERE profile_subscribe_invite_id = pr_profile_subscribe_invite_id;
        
		SELECT
			'Пригласительная ссылка успешно удалена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profiles_check_valid(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED,
    OUT pr_is_valid BOOLEAN,
    OUT pr_error_message TEXT
)
BEGIN
	IF pr_profile_at IS NULL OR pr_profile_to IS NULL THEN
		SET pr_is_valid = false;
        SET pr_error_message = 'Необходимо указать идентификатор для обоих профилей';
	ELSEIF NOT profile_is_exists(pr_profile_at) THEN
		SET pr_is_valid = false;
        SET pr_error_message = 'Подписчика с указанным идентификатором не существует';
	ELSEIF NOT profile_is_exists(pr_profile_to) THEN
		SET pr_is_valid = false;
        SET pr_error_message = 'Профиля с указанным идентификатором не существует';
	ELSE
		SET pr_is_valid = true;
        SET pr_error_message = null;
    END IF;
END//

CREATE PROCEDURE profile_subscribe(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED,
    IN pr_profile_subscribe_invite_id BIGINT UNSIGNED
)
BEGIN
	DECLARE pr_is_accept_status BOOLEAN;

	START TRANSACTION;
    
    CALL profiles_check_valid(pr_profile_at, pr_profile_to, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF pr_profile_at = pr_profile_to THEN
		ROLLBACK;
		SELECT
			'Подписка на себя не допустима' AS message,
			false AS is_valid;
	ELSEIF pr_profile_subscribe_invite_id IS NOT NULL AND profile_subscribe_invite_get_profile_id(pr_profile_subscribe_invite_id) != pr_profile_to THEN
		ROLLBACK;
		SELECT
			'Указанный профиль не является владельцем данной ссылки' AS message,
			false AS is_valid;
	ELSEIF profile_subscribe_is_exists(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Запрос на подписку этому профилю уже был отправлен' AS message,
			false AS is_valid;
	ELSEIF pr_profile_subscribe_invite_id IS NOT NULL AND profile_subscribe_invite_subscribers_count(pr_profile_subscribe_invite_id) >= profile_subscribe_invite_get_inviting_limit(pr_profile_subscribe_invite_id) THEN
		ROLLBACK;
		SELECT
			'Лимит для присоединения по ссылке исчерпан' AS message,
			false AS is_valid;
    ELSE
		SET pr_is_accept_status = profile_subscribe_invite_get_is_auto_accept(pr_profile_subscribe_invite_id);
    
		INSERT INTO profile_subscribe
        SET
			profile_at = pr_profile_at,
            profile_to = pr_profile_to,
            profile_subscribe_invite_id = pr_profile_subscribe_invite_id,
            status = IF(pr_is_accept_status, 'accept', 'request');
        
		SELECT
			'Подписка успешно осуществлена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

-- Используется и при отписке подписчиком, и при удалении профилем подписчика
CREATE PROCEDURE profile_unsubscribe(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profiles_check_valid(pr_profile_at, pr_profile_to, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF NOT profile_subscribe_is_exists(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Указанная подписка не была найдена' AS message,
			false AS is_valid;
    ELSE
		DELETE
        FROM profile_subscribe
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to;
        
		SELECT
			'Отписка успешно осуществлена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_subscribe_accept(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profiles_check_valid(pr_profile_at, pr_profile_to, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF profile_subscribe_is_accept(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Заявка на подписку уже одобрена' AS message,
			false AS is_valid;
    ELSE
		UPDATE profile_subscribe
        SET status = 'accept'
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to;
        
		SELECT
			'Заявка успешно принята' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_subscribe_ignore(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profiles_check_valid(pr_profile_at, pr_profile_to, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF profile_subscribe_is_ignore(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Заявка на подписку уже проигнорирована' AS message,
			false AS is_valid;
    ELSE
		UPDATE profile_subscribe
        SET status = 'ignore'
        WHERE
			profile_at = pr_profile_at AND
            profile_to = pr_profile_to;
        
		SELECT
			'Заявка успешно проигнорирована' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_get_subscribers(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_status ENUM('request', 'ignore', 'accept')
)
BEGIN
	SELECT
		pat.profile_id,
        piat.name,
        piat.avatar_url,
        pat.is_archived,
		pat.is_active,
        piat.details,
        ps.subscribed_at,
        piat.created_at
	FROM
		profile_subscribe AS ps
        INNER JOIN profile AS pat ON ps.profile_at = pat.profile_id
        INNER JOIN profile AS pto ON ps.profile_to = pto.profile_id
        INNER JOIN public_info AS piat ON pat.profile_id = piat.public_info_id
        INNER JOIN public_info AS pito ON pto.profile_id = pito.public_info_id
	WHERE
		pto.profile_id = pr_profile_id AND
        ps.status = pr_status;
END//

CREATE PROCEDURE profile_subscribe_invite_get_info_by_url(IN pr_url_value VARCHAR(25))
BEGIN
	SELECT
		profile_subscribe_invite_id,
        profile_id,
        miniature_url
    FROM profile_subscribe_invite
    WHERE url_value = CAST(pr_url_value AS BINARY);
END//

CREATE PROCEDURE profile_subscribe_invite_get_invited_profiles(IN pr_profile_subscribe_invite_id BIGINT UNSIGNED)
BEGIN
	SELECT
		p.profile_id,
        pi.name,
        pi.avatar_url,
        p.is_archived,
		p.is_active,
        pi.details,
        ps.subscribed_at,
        pi.created_at
	FROM
		profile_subscribe AS ps
        INNER JOIN profile AS p ON ps.profile_at = p.profile_id
        INNER JOIN public_info AS pi ON pi.public_info_id = p.profile_id
	WHERE profile_subscribe_invite_id = pr_profile_subscribe_invite_id;
END//

CREATE PROCEDURE profile_content_item_create(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_value TEXT,
    IN pr_forwarded_id BIGINT UNSIGNED,
    OUT pr_is_valid BOOLEAN,
    OUT pr_error_message TEXT,
    OUT pr_profile_content_item_id BIGINT UNSIGNED
)
BEGIN
    IF pr_profile_id IS NULL OR pr_value IS NULL OR pr_value = '' THEN
        SET pr_is_valid = false;
        SET pr_error_message = 'Необходимо указать автора и отправляемое сообщение';
	ELSEIF NOT profile_is_exists(pr_profile_id) THEN
        SET pr_is_valid = false;
        SET pr_error_message = 'Указанного профиля не существует';
	ELSEIF pr_forwarded_id IS NOT NULL AND NOT profile_content_item_is_exists(pr_forwarded_id) THEN
        SET pr_is_valid = false;
        SET pr_error_message = 'Указанного пересылаемого сообщения не существует';
    ELSE
		INSERT INTO profile_content_item
        SET
			profile_id = pr_profile_id,
            value = pr_value,
            forwarded_id = pr_forwarded_id;
        
        SET pr_profile_content_item_id = LAST_INSERT_ID();
        SET pr_is_valid = true;
    END IF;
END//

CREATE PROCEDURE profile_content_item_edit(
	IN pr_profile_content_item_id BIGINT UNSIGNED,
    IN pr_value TEXT
)
BEGIN
	START TRANSACTION;
    
    IF pr_profile_content_item_id IS NULL OR pr_value IS NULL OR pr_value = '' THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор контента и новое значение' AS message,
            false AS is_valid;
	ELSEIF NOT profile_content_item_is_exists(pr_profile_content_item_id) THEN
		ROLLBACK;
		SELECT
			'Указанного контента не существует' AS message,
			false AS is_valid;
	ELSEIF profile_content_item_get_value(pr_profile_content_item_id) = CAST(pr_value AS BINARY) THEN
		ROLLBACK;
		SELECT
			'Для изменения контента необходимо указать значение, отличающееся от старого' AS message,
			false AS is_valid;
    ELSE
		UPDATE profile_content_item
        SET value = pr_value
        WHERE profile_content_item_id = pr_profile_content_item_id;
        
		SELECT
			'Контент успешно изменён' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_content_item_watch(
	IN pr_profile_content_item_id BIGINT UNSIGNED,
	IN pr_profile_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    IF pr_profile_content_item_id IS NULL OR pr_profile_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать просматриваемый контент и профиль' AS message,
            false AS is_valid;
	ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанного профиля не существует' AS message,
			false AS is_valid;
	ELSEIF NOT profile_content_item_is_exists(pr_profile_content_item_id) THEN
		ROLLBACK;
		SELECT
			'Указанного контента не существует' AS message,
			false AS is_valid;
    ELSE
		IF NOT profile_get_is_hide_watch(pr_profile_id) THEN
			INSERT INTO profile_content_item_watch
			SET
				profile_content_item_id = pr_profile_content_item_id,
                profile_id = pr_profile_id;
        END IF;
        
		SELECT
			'Информация о просмотре учтена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_is_hide_watch_set(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_is_hide_watch BOOLEAN
)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile
		SET is_hide_watch = pr_is_hide_watch
        WHERE profile_id = pr_profile_id;
        
        IF pr_is_hide_watch THEN
			DELETE
            FROM profile_content_item_watch
            WHERE
				profile_id = pr_profile_id AND
                profile_content_item_watch_id > 0; -- Чтобы не выключать SafeMode
        END IF;
        
		SELECT
			'Настройки профиля успешно изменены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_content_item_report(
	IN pr_profile_content_item_id BIGINT UNSIGNED,
	IN pr_reporter_account_id BIGINT UNSIGNED,
    IN pr_details VARCHAR(100)
)
BEGIN
	DECLARE pr_profile_id BIGINT UNSIGNED;
    DECLARE pr_account_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    IF pr_profile_content_item_id IS NULL OR pr_reporter_account_id IS NULL OR pr_details IS NULL OR pr_details = '' THEN
		ROLLBACK;
		SELECT
			'Необходимо указать контент, свой аккаунт и детали для составления жалобы' AS message,
            false AS is_valid;
	ELSEIF NOT profile_content_item_is_exists(pr_profile_content_item_id) THEN
		ROLLBACK;
		SELECT
			'Указанного контента не существует' AS message,
			false AS is_valid;
	ELSEIF NOT account_is_exists_by_id(pr_reporter_account_id) THEN
		ROLLBACK;
		SELECT
			'Указанного аккаунта не существует' AS message,
			false AS is_valid;
	ELSEIF profile_content_item_report_is_exists(pr_profile_content_item_id, pr_reporter_account_id) THEN
		ROLLBACK;
		SELECT
			'Вами уже была отправлена жалоба на указанный контент' AS message,
			false AS is_valid;
    ELSE
		SET pr_profile_id = profile_content_item_get_profile_id(pr_profile_content_item_id);
        SET pr_account_id = profile_get_account_id(pr_profile_id);
        
        INSERT INTO profile_content_item_report
        SET
			profile_content_item_id = pr_profile_content_item_id,
            profile_id = pr_profile_id,
            account_id = pr_account_id,
            reporter_account_id = pr_reporter_account_id,
            details = pr_details;
        
		SELECT
			'Жалоба на контент успешно отправлена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_message_send(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED,
    IN pr_value TEXT,
    IN pr_forwarded_content_item_id BIGINT UNSIGNED,
    OUT pr_profile_message_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profile_content_item_create(pr_profile_at, pr_value, pr_forwarded_content_item_id, @is_valid, @error_message, @profile_content_item_id);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@error_message AS message,
			false AS is_valid;
	ELSEIF pr_profile_to IS NULL OR NOT profile_is_exists(pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Получатель сообщения не был найден' AS message,
			false AS is_valid;
	ELSEIF NOT profile_message_is_can_sended(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'У вас нет доступа к отправке сообщений этому профилю' AS message,
			false AS is_valid;
    ELSE
		INSERT INTO profile_message
        SET
			profile_content_item_id = @profile_content_item_id,
            profile_to = pr_profile_to,
            is_checked = IFNULL(pr_profile_at = pr_profile_to, false); -- Сообщения из избранного автоматически считаются за прочитанные
        
        SET pr_profile_message_id = LAST_INSERT_ID();
        
		SELECT
			'Сообщение успешно отправлено' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_message_check(IN pr_profile_message_id BIGINT UNSIGNED)
BEGIN
	DECLARE pr_profile_to BIGINT UNSIGNED;
	
	START TRANSACTION;
    
    SET pr_profile_to = profile_message_get_profile_to(pr_profile_message_id);
    IF pr_profile_message_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать сообщение для просмотра' AS message,
            false AS is_valid;
    ELSEIF NOT profile_message_is_exists(pr_profile_message_id) THEN
		ROLLBACK;
		SELECT
			'Указанного сообщения не существует' AS message,
			false AS is_valid;
    ELSE
		IF NOT profile_message_get_is_checked(pr_profile_message_id) THEN
			UPDATE profile_message
            SET is_checked = true
            WHERE
				profile_to = pr_profile_to AND
                is_checked = false AND
				profile_message_id <= pr_profile_message_id;
        END IF;
        
		SELECT
			'Информация о просмотре учтена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_message_delete(IN pr_profile_message_id BIGINT UNSIGNED)
BEGIN
	DECLARE pr_profile_content_item_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    SET pr_profile_content_item_id = profile_message_get_profile_content_item_id(pr_profile_message_id);
    IF pr_profile_message_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать сообщение для удаления' AS message,
            false AS is_valid;
    ELSEIF NOT profile_message_is_exists(pr_profile_message_id) THEN
		ROLLBACK;
		SELECT
			'Указанного сообщения не существует' AS message,
			false AS is_valid;
    ELSE
		DELETE
        FROM profile_content_item
        WHERE profile_content_item_id = pr_profile_content_item_id;
        
		SELECT
			'Сообщение удалено' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_content_item_get_info(IN pr_profile_content_item_id BIGINT UNSIGNED)
BEGIN
	SELECT
		profile_id,
		forwarded_id,
		value,
		created_at
	FROM profile_content_item
	WHERE profile_content_item_id = pr_profile_content_item_id;
END//

CREATE PROCEDURE profile_messages_get_from(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED,
    IN pr_profile_message_id_start BIGINT UNSIGNED, -- Применимый сценарий, сообщения подгружаются по мере листания чата
    IN pr_messages_count INT UNSIGNED
)
BEGIN
	SELECT
		m.profile_message_id,
		ci.profile_content_item_id,
		ci.value,
        ci.created_at,
        m.is_checked,
        ci.forwarded_id
    FROM
		profile_message AS m
        INNER JOIN profile_content_item AS ci USING(profile_content_item_id)
    WHERE
		ci.profile_id = pr_profile_at AND
        m.profile_to = pr_profile_to AND
        profile_message_id < pr_profile_message_id_start
	ORDER BY m.profile_message_id DESC
    LIMIT pr_messages_count;
END//

CREATE PROCEDURE profile_publication_create(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_value TEXT,
    IN pr_forwarded_content_item_id BIGINT UNSIGNED,
    OUT pr_profile_publication_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profile_content_item_create(pr_profile_id, pr_value, pr_forwarded_content_item_id, @is_valid, @error_message, @profile_content_item_id);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@error_message AS message,
			false AS is_valid;
    ELSE
		INSERT INTO profile_publication
        SET profile_content_item_id = @profile_content_item_id;
        
        SET pr_profile_publication_id = LAST_INSERT_ID();
        
		SELECT
			'Контент успешно опубликован' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_publication_delete(IN pr_profile_publication_id BIGINT UNSIGNED)
BEGIN
	DECLARE pr_profile_content_item_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    SET pr_profile_content_item_id = profile_publication_get_profile_content_item_id(pr_profile_publication_id);
    IF pr_profile_publication_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать публикацию для удаления' AS message,
            false AS is_valid;
    ELSEIF NOT profile_publication_is_exists(pr_profile_publication_id) THEN
		ROLLBACK;
		SELECT
			'Указанной публикации не существует' AS message,
			false AS is_valid;
    ELSE
		DELETE
        FROM profile_content_item
        WHERE profile_content_item_id = pr_profile_content_item_id;
        
		SELECT
			'Публикация удалена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_publication_comment_create() -- +Проверка подписчик ли
CREATE PROCEDURE profile_publication_comment_delete() -- +Проверка создатель ли коммента
CREATE PROCEDURE profile_publication_comment_get_from() -- +Проверка подписчик ли

CREATE PROCEDURE profile_group_chat_create()
CREATE PROCEDURE profile_group_chat_delete() -- +Проверка на владение
CREATE PROCEDURE profile_group_chat_member_add() -- +Проверка на право модерации
CREATE PROCEDURE profile_group_chat_member_delete() -- +Проверка на право модерации
CREATE PROCEDURE profile_group_chat_member_custom_title_set() -- +Проверка на право модерации
CREATE PROCEDURE profile_group_chat_member_status_set() -- +Проверка на владение
CREATE PROCEDURE profile_group_chat_member_transfer_ownership() -- +Проверка на владение
CREATE PROCEDURE profile_group_chat_get_members() -- +Проверка состоит ли в чате
CREATE PROCEDURE profile_group_chat_message_send() -- +Проверка состоит ли в чате
CREATE PROCEDURE profile_group_chat_message_delete() -- +Проверка состоит ли в чате

CREATE PROCEDURE profile_publication_check() -- +Проверка подписчик ли
CREATE PROCEDURE profile_group_chat_message_check() -- +Проверка состоит ли в чате
CREATE PROCEDURE profile_get_messages() -- И из индивидуальных чатов, и из групповых, с индикацией просмотренности, количеством новых сообщений, последним сообщением и индикатором самого профиля (если сообщение) или группового чата (соответственно)
CREATE PROCEDURE profile_get_publications() -- Если в параметре профиля null, то лента со всеми публикациями из подписок + количество комментариев

DELIMITER ;

-- TODO
/*
- При удалении профиля передавать права на владения групповыми чатами другим людям (чекнуть и другие RESTRICT)
- При удалении аккаунта это всё делать в автоматическом режиме
- Указатель на последний просмотренный пост или таблица с просмотренными постами
- Указатель на последнее просмотренное групповое сообщение или таблица с просмотренными сообщениями
- Функция подсчёта новых публикаций в ленте (или у отдельного профиля)
- Функция подсчёта новых групповых сообщений
- Просмотр пересылаемого контента только при наличии подписки
*/

-- Шаблон для хранимки
/*
CREATE PROCEDURE (
	
)
BEGIN
	START TRANSACTION;
    
    IF  IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать ' AS message,
            false AS is_valid;
    ELSEIF NOT  THEN
		ROLLBACK;
		SELECT
			' не существует' AS message,
			false AS is_valid;
    ELSE
		
        
		SELECT
			'Успех' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//
*/