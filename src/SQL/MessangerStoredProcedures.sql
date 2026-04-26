DELIMITER //

CREATE PROCEDURE account_create(
	IN pr_phone VARCHAR(17),
    IN pr_first_name VARCHAR(25),
    IN pr_last_name VARCHAR(25),
    OUT pr_account_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    IF pr_phone IS NULL OR pr_first_name IS NULL OR pr_last_name IS NULL OR pr_first_name = '' OR pr_last_name = '' THEN
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

-- Для передачи прав владения группой приемникам при удалении профиля
CREATE PROCEDURE successors_assign_group_owners(IN pr_profile_id BIGINT UNSIGNED)
BEGIN
	DECLARE pr_done BOOLEAN DEFAULT false;
	DECLARE pr_profile_group_chat_id BIGINT UNSIGNED;
    DECLARE pr_new_owner_profile_id BIGINT UNSIGNED;
    
	DECLARE profile_group_chat_id_where_owner_cur CURSOR FOR
		SELECT profile_group_chat_id
        FROM profile_group_chat_member
        WHERE
			profile_id = pr_profile_id AND
            status = 'owner';
	
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pr_done = true;
    
	OPEN profile_group_chat_id_where_owner_cur;
    
    read_loop: LOOP
        FETCH profile_group_chat_id_where_owner_cur INTO pr_profile_group_chat_id;
        
        IF pr_done THEN
            LEAVE read_loop;
        END IF;
        
        IF profile_group_chat_member_get_count(pr_profile_group_chat_id) > 1 THEN
			SELECT profile_id INTO pr_new_owner_profile_id
            FROM profile_group_chat_member
            WHERE
				profile_group_chat_id = pr_profile_group_chat_id AND
				profile_id > pr_profile_id
			LIMIT 1;
            
			UPDATE profile_group_chat
			SET profile_id = pr_new_owner_profile_id
			WHERE profile_group_chat_id = pr_profile_group_chat_id;
			
            DELETE
			FROM profile_group_chat_member
            WHERE
				profile_group_chat_id = pr_profile_group_chat_id AND
                profile_id = pr_profile_id;
                
			IF EXISTS (
				SELECT 1
                FROM profile_group_chat_member
                WHERE
					profile_group_chat_id = pr_profile_group_chat_id AND
                    status = 'owner'
            ) THEN
				ROLLBACK;
				SELECT
					'Ошибка удаления владельца чата' AS message,
					false AS is_valid;
				LEAVE read_loop;
			END IF;
		
			UPDATE profile_group_chat_member
			SET status = 'owner'
			WHERE
				profile_group_chat_id = pr_profile_group_chat_id AND
                profile_id = pr_new_owner_profile_id;
		ELSE
			DELETE
            FROM profile_group_chat
            WHERE profile_group_chat_id = pr_profile_group_chat_id;
        END IF;
    END LOOP;
    
    CLOSE profile_group_chat_id_where_owner_cur;
END//

CREATE PROCEDURE account_delete(IN pr_phone VARCHAR(17))
BEGIN
	DECLARE pr_done BOOLEAN DEFAULT false;
    DECLARE pr_profile_id BIGINT UNSIGNED;
    
	DECLARE account_profiles_id CURSOR FOR
		SELECT profile_id
        FROM profile
        WHERE account_id = account_get_id(pr_phone);
	
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pr_done = true;
    
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
		OPEN account_profiles_id;
		read_loop: LOOP
			FETCH account_profiles_id INTO pr_profile_id;
			
			IF pr_done THEN
				LEAVE read_loop;
			END IF;
			
			CALL successors_assign_group_owners(pr_profile_id);
		END LOOP;
		CLOSE account_profiles_id;
    
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
    IF pr_account_id IS NULL OR pr_name IS NULL OR pr_name = '' OR pr_account_profile_limit IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать аккаунт, имя профиля и лимит профилей для его создания' AS message,
            false AS is_valid;
    ELSEIF NOT account_is_exists_by_id(pr_account_id) THEN
		ROLLBACK;
		SELECT
			'Указанного аккаунта не существует' AS message,
			false AS is_valid;
    ELSEIF pr_account_profile_count >= pr_account_profile_limit THEN
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
		CALL successors_assign_group_owners(pr_profile_id);
        
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
    
    IF pr_profile_id IS NULL OR pr_name IS NULL OR pr_name = '' THEN
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
	ELSEIF profile_subscribe_is_exists(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Запрос на подписку этому профилю уже был отправлен' AS message,
			false AS is_valid;
	ELSEIF pr_profile_subscribe_invite_id IS NOT NULL AND profile_subscribe_invite_get_profile_id(pr_profile_subscribe_invite_id) != pr_profile_to THEN
		ROLLBACK;
		SELECT
			'Указанный профиль не является владельцем данной ссылки' AS message,
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
	ELSEIF NOT profile_subscribe_is_exists(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Указанная подписка не была найдена' AS message,
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
	ELSEIF NOT profile_subscribe_is_exists(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Указанная подписка не была найдена' AS message,
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
		profile_id,
        name,
        avatar_url,
        is_archived,
		is_active,
        details,
        subscribed_at,
        created_at
	FROM
		profile_subscribe
        INNER JOIN profile ON profile_at = profile_id
        INNER JOIN public_info ON profile_id = public_info_id
	WHERE
		profile_to = pr_profile_id AND
        status = pr_status;
END//

CREATE PROCEDURE profile_get_subscriptions(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_status ENUM('request', 'accept')
)
BEGIN
	SELECT
		profile_id,
        name,
        avatar_url,
        profile_get_new_publications_count(pr_profile_id, profile_id) AS new_publications_count,
        is_archived,
		is_active,
        details,
        subscribed_at,
        created_at
	FROM
		profile_subscribe
        INNER JOIN profile ON profile_to = profile_id
        INNER JOIN public_info ON profile_id = public_info_id
	WHERE
		profile_at = pr_profile_id AND
        CASE
			WHEN pr_status = 'request' THEN status IN ('request', 'ignore')
			ELSE status = 'accept'
		END;
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
	ELSEIF pr_profile_at != pr_profile_to AND NOT profile_message_is_can_sended(pr_profile_at, pr_profile_to) THEN
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
        ci.edited_at,
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

CREATE PROCEDURE profile_publication_comment_create(
	IN pr_profile_publication_id BIGINT UNSIGNED,
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_value TEXT,
    IN pr_forwarded_content_item_id BIGINT UNSIGNED,
    OUT pr_profile_publication_comment_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profile_content_item_create(pr_profile_id, pr_value, pr_forwarded_content_item_id, @is_valid, @error_message, @profile_content_item_id);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@error_message AS message,
			false AS is_valid;
	ELSEIF NOT profile_publication_is_exists(pr_profile_publication_id) THEN
		ROLLBACK;
		SELECT
			'Указанной публикации не существует' AS message,
			false AS is_valid;
	ELSEIF NOT profile_subscribe_is_exists(pr_profile_id, profile_content_item_get_profile_id(profile_publication_get_profile_content_item_id(pr_profile_publication_id))) AND pr_profile_id != profile_content_item_get_profile_id(profile_publication_get_profile_content_item_id(pr_profile_publication_id)) THEN
		ROLLBACK;
		SELECT
			'Вы не можете оставить комментарии к этому посту' AS message,
			false AS is_valid;
    ELSE
		INSERT INTO profile_publication_comment
        SET
			profile_publication_id = pr_profile_publication_id,
            profile_content_item_id = @profile_content_item_id;
        
        SET pr_profile_publication_comment_id = LAST_INSERT_ID();
        
		SELECT
			'Комментарий успешно опубликован' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_publication_comment_delete(IN pr_profile_publication_comment_id BIGINT UNSIGNED)
BEGIN
	DECLARE pr_profile_content_item_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    SET pr_profile_content_item_id = profile_publication_comment_get_profile_content_item_id(pr_profile_publication_comment_id);
    IF pr_profile_publication_comment_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать комментарий для удаления' AS message,
            false AS is_valid;
    ELSEIF NOT profile_publication_comment_is_exists(pr_profile_publication_comment_id) THEN
		ROLLBACK;
		SELECT
			'Указанного комментария не существует' AS message,
			false AS is_valid;
    ELSE
		DELETE
        FROM profile_content_item
        WHERE profile_content_item_id = pr_profile_content_item_id;
        
		SELECT
			'Комментарий удалён' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_publication_comment_get_from(IN pr_profile_publication_id BIGINT UNSIGNED)
BEGIN
	SELECT
		profile_publication_comment_id,
		ci.profile_content_item_id,
		value AS content_item_value,
		ci.created_at AS content_item_created_at,
		edited_at AS content_item_edited_at,
		forwarded_id AS content_item_forwarded_id,
		public_info_id AS profile_id,
		name AS profile_name,
		avatar_url AS profile_avatar_url
	FROM
		profile_publication_comment AS c
		INNER JOIN profile_content_item AS ci USING(profile_content_item_id)
		INNER JOIN public_info AS pi ON profile_id = public_info_id
	WHERE profile_publication_id = pr_profile_publication_id;
END//

CREATE PROCEDURE profile_group_chat_create(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_name VARCHAR(40),
    IN pr_details VARCHAR(100),
    IN pr_avatar_url TEXT,
    OUT pr_profile_group_chat_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
	CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSEIF pr_name IS NULL OR pr_name = '' THEN
		ROLLBACK;
		SELECT
			'Необходимо указать имя для группового чата' AS message,
            false AS is_valid;
    ELSE
		INSERT INTO public_info
        SET
			name = pr_name,
            details = pr_details,
            avatar_url = pr_avatar_url;
        
        SET pr_profile_group_chat_id = LAST_INSERT_ID();
        
        INSERT INTO profile_group_chat
        SET
			profile_group_chat_id = pr_profile_group_chat_id,
            profile_id = pr_profile_id;
		
        INSERT INTO profile_group_chat_member
        SET
			profile_group_chat_id = pr_profile_group_chat_id,
            profile_id = pr_profile_id,
            status = 'owner';
        
		SELECT
			'Групповой чат успешно создан' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_delete(IN pr_profile_group_chat_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
	
    IF pr_profile_group_chat_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор группового чата' AS message,
            false AS is_valid;
	ELSEIF NOT profile_group_chat_is_exists(pr_profile_group_chat_id) THEN
		ROLLBACK;
		SELECT
			'Указанного группового чата не существует' AS message,
            false AS is_valid;
    ELSE
		DELETE FROM profile_group_chat
        WHERE profile_group_chat_id = pr_profile_group_chat_id;
    
		DELETE FROM public_info
        WHERE public_info_id = pr_profile_group_chat_id;
        
		SELECT
			'Групповой чат успешно удалён' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_add(
	IN pr_profile_group_chat_id BIGINT UNSIGNED,
    IN pr_profile_id BIGINT UNSIGNED,
    IN pr_status ENUM('owner', 'moderator', 'member', 'blocked'),
    IN pr_custom_title VARCHAR(20),
    OUT pr_profile_group_chat_member_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSEIF pr_profile_group_chat_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификаторы группового чата' AS message,
            false AS is_valid;
    ELSEIF NOT profile_group_chat_is_exists(pr_profile_group_chat_id) THEN
		ROLLBACK;
		SELECT
			'Указанного группового чата не существует' AS message,
			false AS is_valid;
	ELSEIF profile_group_chat_member_is_exists_by_info(pr_profile_group_chat_id, pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанный пользователь уже состоит в чате' AS message,
			false AS is_valid;
	ELSEIF pr_status = 'owner' THEN
		ROLLBACK;
		SELECT
			'Для назначения владельца, необходимо передать права на группу другому участнику' AS message,
			false AS is_valid;
    ELSE
		INSERT INTO profile_group_chat_member
        SET
			profile_group_chat_id = pr_profile_group_chat_id,
            profile_id = pr_profile_id,
            status = IFNULL(pr_status, 'member'),
            custom_title = pr_custom_title;
        
        SET pr_profile_group_chat_member_id = LAST_INSERT_ID();
        
		SELECT
			'Участник успешно добавлен' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_check_valid(
	IN pr_profile_group_chat_member_id BIGINT UNSIGNED,
    OUT pr_is_valid BOOLEAN,
    OUT pr_message TEXT
)
BEGIN
    IF pr_profile_group_chat_member_id IS NULL THEN
		SET pr_is_valid = false;
        SET pr_message = 'Необходимо указать идентификатор члена группы';
    ELSEIF NOT profile_group_chat_member_is_exists_by_id(pr_profile_group_chat_member_id) THEN
		SET pr_is_valid = false;
        SET pr_message = 'Указанного члена группы не существует';
	ELSE
		SET pr_is_valid = true;
        SET pr_message = null;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_delete(IN pr_profile_group_chat_member_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    CALL profile_group_chat_member_check_valid(pr_profile_group_chat_member_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF profile_group_chat_member_is_owner(pr_profile_group_chat_member_id) THEN
		ROLLBACK;
		SELECT
			'Перед удалением владельца, необходимо передать права на группу другому участнику' AS message,
            false AS is_valid;
    ELSE
		DELETE FROM profile_group_chat_member
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id;
        
		SELECT
			'Член группы успешно удалён' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_custom_title_set(
	IN pr_profile_group_chat_member_id BIGINT UNSIGNED,
    IN pr_custom_title VARCHAR(20)
)
BEGIN
	START TRANSACTION;
    
    CALL profile_group_chat_member_check_valid(pr_profile_group_chat_member_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile_group_chat_member
        SET custom_title = pr_custom_title
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id;
        
		SELECT
			'Кличка успешно изменена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_block(IN pr_profile_group_chat_member_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    CALL profile_group_chat_member_check_valid(pr_profile_group_chat_member_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF profile_group_chat_member_is_owner(pr_profile_group_chat_member_id) THEN
		ROLLBACK;
		SELECT
			'Блокировать владельца группы не допустимо' AS message,
            false AS is_valid;
    ELSE
		UPDATE profile_group_chat_member
        SET status = 'blocked'
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id;
        
		SELECT
			'Участник успешно заблокирован' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_set_moderator(IN pr_profile_group_chat_member_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    CALL profile_group_chat_member_check_valid(pr_profile_group_chat_member_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF profile_group_chat_member_is_owner(pr_profile_group_chat_member_id) THEN
		ROLLBACK;
		SELECT
			'Понижать права владельца до модератора не допустимо' AS message,
            false AS is_valid;
    ELSE
		UPDATE profile_group_chat_member
        SET status = 'moderator'
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id;
        
		SELECT
			'Участник успешно назначен модератором' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_set_member(IN pr_profile_group_chat_member_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    CALL profile_group_chat_member_check_valid(pr_profile_group_chat_member_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
	ELSEIF profile_group_chat_member_is_owner(pr_profile_group_chat_member_id) THEN
		ROLLBACK;
		SELECT
			'Понижать права владельца до участника не допустимо' AS message,
            false AS is_valid;
    ELSE
		UPDATE profile_group_chat_member
        SET status = 'member'
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id;
        
		SELECT
			'Права участника сброшены' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_member_transfer_ownership(IN pr_profile_group_chat_member_id BIGINT UNSIGNED)
BEGIN
	DECLARE pr_profile_group_chat_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    SET pr_profile_group_chat_id = profile_group_chat_member_get_profile_group_chat_id(pr_profile_group_chat_member_id);
    CALL profile_group_chat_member_check_valid(pr_profile_group_chat_member_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSE
		UPDATE profile_group_chat_member
        SET status = 'moderator'
        WHERE
			profile_group_chat_id = pr_profile_group_chat_id AND
			status = 'owner' AND
            profile_group_chat_member_id > 0; -- Чтобы не отключать safe-mode
    
		UPDATE profile_group_chat_member
        SET status = 'owner'
        WHERE profile_group_chat_member_id = pr_profile_group_chat_member_id;
        
        UPDATE profile_group_chat
        SET profile_id = profile_group_chat_member_get_profile_id(pr_profile_group_chat_member_id)
        WHERE profile_group_chat_id = pr_profile_group_chat_id;
        
		SELECT
			'Права на групповой чат успешно переданы' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_members_get_from(IN pr_profile_group_chat_id BIGINT UNSIGNED)
BEGIN
	SELECT
		profile_group_chat_member_id,
        custom_title,
		p.profile_id,
        name,
        avatar_url,
        is_archived,
		is_active,
        details,
        created_at
	FROM
		profile_group_chat_member AS cm
        INNER JOIN profile AS p USING(profile_id)
        INNER JOIN public_info AS pi ON pi.public_info_id = p.profile_id
	WHERE profile_group_chat_id = pr_profile_group_chat_id;
END//

CREATE PROCEDURE profile_group_chat_message_send(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_profile_group_chat_id BIGINT UNSIGNED,
    IN pr_value TEXT,
    IN pr_forwarded_content_item_id BIGINT UNSIGNED,
    OUT pr_profile_group_chat_message_id BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    CALL profile_content_item_create(pr_profile_id, pr_value, pr_forwarded_content_item_id, @is_valid, @error_message, @profile_content_item_id);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@error_message AS message,
			false AS is_valid;
	ELSEIF pr_profile_group_chat_id IS NULL OR NOT profile_group_chat_is_exists(pr_profile_group_chat_id) THEN
		ROLLBACK;
		SELECT
			'Групповой чат не был найден' AS message,
			false AS is_valid;
	ELSEIF NOT profile_group_chat_member_is_exists_by_info(pr_profile_group_chat_id, pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'У вас нет доступа к отправке сообщений в этот чат' AS message,
			false AS is_valid;
    ELSE
		INSERT INTO profile_group_chat_message
        SET
			profile_content_item_id = @profile_content_item_id,
            profile_group_chat_id = pr_profile_group_chat_id;
        
        SET pr_profile_group_chat_message_id = LAST_INSERT_ID();
        
		SELECT
			'Сообщение успешно отправлено' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_message_delete(IN pr_profile_group_chat_message_id BIGINT UNSIGNED)
BEGIN
	DECLARE pr_profile_content_item_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    SET pr_profile_content_item_id = profile_group_chat_message_get_profile_content_item_id(pr_profile_group_chat_message_id);
    IF pr_profile_group_chat_message_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать сообщение для удаления' AS message,
            false AS is_valid;
    ELSEIF NOT profile_group_chat_message_is_exists(pr_profile_group_chat_message_id) THEN
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

CREATE PROCEDURE profile_group_chat_messages_get_from(
	IN pr_profile_id BIGINT UNSIGNED,
	IN pr_profile_group_chat_id BIGINT UNSIGNED,
    IN pr_profile_group_chat_message_id_start BIGINT UNSIGNED, -- Применимый сценарий, сообщения подгружаются по мере листания чата
    IN pr_messages_count INT UNSIGNED
)
BEGIN
	SELECT
		profile_group_chat_message_id,
		profile_content_item_id,
		value,
		ci.created_at,
		edited_at,
		profile_group_chat_message_is_checked(pr_profile_id, profile_group_chat_message_id) AS is_checked,
		forwarded_id,
		profile_id,
		name,
		avatar_url
	FROM
		profile_group_chat_message AS m
		INNER JOIN profile_content_item AS ci USING (profile_content_item_id)
		INNER JOIN public_info AS pi ON profile_id = public_info_id
	WHERE
		profile_group_chat_id = pr_profile_group_chat_id AND
		profile_group_chat_message_id < pr_profile_group_chat_message_id_start
	ORDER BY profile_group_chat_message_id DESC
	LIMIT pr_messages_count;
END//

CREATE PROCEDURE profile_publication_check(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_profile_publication_id BIGINT UNSIGNED
)
BEGIN
	DECLARE pr_profile_to BIGINT UNSIGNED;
    DECLARE pr_last_profile_publication_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    SET pr_profile_to = profile_content_item_get_profile_id(profile_publication_get_profile_content_item_id(pr_profile_publication_id));
    SET pr_last_profile_publication_id = profile_publication_checked_get_profile_publication_id(pr_profile_id, pr_profile_to);
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSEIF pr_profile_publication_id IS NULL OR NOT profile_publication_is_exists(pr_profile_publication_id) THEN
		ROLLBACK;
		SELECT
			'Указанная публикация не была найдена' AS message,
			false AS is_valid;
	ELSEIF NOT profile_subscribe_is_exists(pr_profile_id, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'У вас нет доступа к просмотру указанной публикации' AS message,
			false AS is_valid;
    ELSE
		IF profile_publication_checked_is_exists(pr_profile_id, pr_profile_to) THEN
			UPDATE profile_publication_checked
            SET profile_publication_id = IF(pr_profile_publication_id > pr_last_profile_publication_id, pr_profile_publication_id, pr_last_profile_publication_id)
            WHERE
				profile_at = pr_profile_id AND
                profile_to = pr_profile_to;
        ELSE
			INSERT INTO profile_publication_checked
            SET
				profile_at = pr_profile_id,
                profile_to = pr_profile_to,
                profile_publication_id = pr_profile_publication_id;
        END IF;
        
		SELECT
			'Информация о просмотре публикации учтена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_group_chat_message_check(
	IN pr_profile_id BIGINT UNSIGNED,
    IN pr_profile_group_chat_message_id BIGINT UNSIGNED
)
BEGIN
	DECLARE pr_profile_group_chat_id BIGINT UNSIGNED;
    DECLARE pr_last_profile_group_chat_message_id BIGINT UNSIGNED;

	START TRANSACTION;
    
    SET pr_profile_group_chat_id = profile_group_chat_message_get_profile_group_chat_id(pr_profile_group_chat_message_id);
    SET pr_last_profile_group_chat_message_id = profile_group_chat_message_checked_get_group_chat_message_id(pr_profile_id, pr_profile_group_chat_id);
    
    CALL profile_check_valid(pr_profile_id, @is_valid, @message);
    
    IF NOT @is_valid THEN
		ROLLBACK;
		SELECT
			@message AS message,
            false AS is_valid;
    ELSEIF pr_profile_group_chat_message_id IS NULL OR NOT profile_group_chat_message_is_exists(pr_profile_group_chat_message_id) THEN
		ROLLBACK;
		SELECT
			'Указанное сообщение не было найдено' AS message,
			false AS is_valid;
	ELSEIF NOT profile_group_chat_member_is_exists_by_info(pr_profile_group_chat_id, pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'У вас нет доступа к просмотру указанного сообщения' AS message,
			false AS is_valid;
    ELSE
		IF profile_group_chat_message_checked_is_exists(pr_profile_id, pr_profile_group_chat_id) THEN
			UPDATE profile_group_chat_message_checked
            SET profile_group_chat_message_id = IF(pr_profile_group_chat_message_id > pr_last_profile_group_chat_message_id, pr_profile_group_chat_message_id, pr_last_profile_group_chat_message_id)
            WHERE
				profile_id = pr_profile_id AND
                profile_group_chat_id = pr_profile_group_chat_id;
        ELSE
			INSERT INTO profile_group_chat_message_checked
            SET
				profile_id = pr_profile_id,
                profile_group_chat_id = pr_profile_group_chat_id,
                profile_group_chat_message_id = pr_profile_group_chat_message_id;
        END IF;
        
		SELECT
			'Информация о просмотре сообщения учтена' AS message,
            true AS is_valid;
        COMMIT;
    END IF;
END//

CREATE PROCEDURE profile_publications_get_from(
	IN pr_profile_at BIGINT UNSIGNED,
	IN pr_profile_to BIGINT UNSIGNED, -- Если null, возвращаются публикации от всех профилей (на которые подписан pr_profile_at)
	IN pr_profile_publication_id_start BIGINT UNSIGNED, -- Применимый сценарий, публикации подгружаются по мере листания ленты/стены
    IN pr_publications_count INT UNSIGNED
)
BEGIN
	WITH subscriptions AS (
		SELECT profile_to
		FROM profile_subscribe
		WHERE profile_at = pr_profile_at
    )
	SELECT
		profile_publication_id,
		profile_content_item_id,
		value,
        profile_publication_get_comments_count(profile_publication_id) AS comments_count,
		ci.created_at,
		edited_at,
		profile_publication_is_checked(pr_profile_at, profile_publication_id) AS is_checked,
		forwarded_id,
		profile_id,
		name,
		avatar_url
	FROM
		profile_publication AS p
        INNER JOIN profile_content_item AS ci USING(profile_content_item_id)
        INNER JOIN public_info AS pi ON public_info_id = profile_id
        INNER JOIN subscriptions AS s ON profile_id = profile_to -- Как фильтр для подписок
	WHERE
		(pr_profile_to IS NULL OR profile_id = pr_profile_to) AND
		profile_publication_id < pr_profile_publication_id_start
	ORDER BY
		is_checked,
		profile_publication_id DESC
	LIMIT pr_publications_count;
END//

CREATE PROCEDURE profile_get_messages(IN pr_profile_id BIGINT UNSIGNED)
BEGIN
	WITH
		interlocutors_with_last_message_id AS (
			SELECT
				IF(ci.profile_id = pr_profile_id, m.profile_to, ci.profile_id) AS interlocutor_id,
				MAX(profile_message_id) AS last_message_id,
                SUM(is_checked = false) AS new_messages_count
			FROM
				profile_content_item AS ci
				INNER JOIN profile_message AS m USING(profile_content_item_id)
			WHERE pr_profile_id IN(ci.profile_id, m.profile_to)
			GROUP BY interlocutor_id
        ),
		group_chats AS (
			SELECT profile_group_chat_id
            FROM profile_group_chat_member
            WHERE profile_id = pr_profile_id
		)
	SELECT
		interlocutor_id AS chat_id,
        'profile' AS chat_type,
        last_message_id,
        IF(interlocutor_id = pr_profile_id, true, profile_get_is_active(interlocutor_id)) is_active,
        profile_content_item_get_created_at(profile_message_get_profile_content_item_id(last_message_id)) AS created_at,
        profile_message_get_is_checked(last_message_id) AS is_checked,
		name,
        avatar_url,
		profile_content_item_get_value(profile_message_get_profile_content_item_id(last_message_id)) AS last_message_value,
		new_messages_count
	FROM
		interlocutors_with_last_message_id
        INNER JOIN public_info ON interlocutor_id = public_info_id
    UNION ALL
    SELECT
		profile_group_chat_id AS chat_id,
        'group_chat' AS chat_type,
        last_message_id,
        true AS is_active, -- Пока что для групповых чатов не планируется настройка их активности, они всегда могут принимать сообщения
        profile_content_item_get_created_at(profile_group_chat_message_get_profile_content_item_id(last_message_id)) AS created_at,
        profile_group_chat_message_is_checked(pr_profile_id, last_message_id) AS is_checked,
		name,
        avatar_url,
		profile_content_item_get_value(profile_group_chat_message_get_profile_content_item_id(last_message_id)) AS last_message_value,
		profile_group_chat_get_new_messages_count(profile_group_chat_id, pr_profile_id) AS new_messages_count
	FROM
		(
			SELECT
				profile_group_chat_id,
                profile_group_chat_get_last_message_id(profile_group_chat_id) AS last_message_id
            FROM group_chats
        ) AS group_chats_with_last_message_id
        INNER JOIN public_info ON profile_group_chat_id = public_info_id
	ORDER BY last_message_id DESC;
END//

DELIMITER ;

-- Перспективы развития
/*
- Приглашения на групповые чаты (возможно также вынести оформление ссылок в отдельную таблицу)
- Аудио-сообщения
- Счета с монетами
- Premium-подписка
- Скрытие просмотров сделать только для premium-пользователей
- Выбор рамки для public_info (premium)
- Период в который допустима отправка сообщений (premium)
- Увеличить лимит профилей (premium)
- Транскибирование аудио (premium)
*/