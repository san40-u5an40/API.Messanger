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

CREATE PROCEDURE profile_delete(IN pr_profile_id BIGINT UNSIGNED)
BEGIN
	START TRANSACTION;
    
    IF pr_profile_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор профиля для его удаления' AS message,
            false AS is_valid;
    ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанного профиля не существует' AS message,
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
    
    IF pr_profile_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор профиля' AS message,
            false AS is_valid;
    ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанного профиля не существует' AS message,
			false AS is_valid;
    ELSE
		UPDATE profile
		SET is_last_selected = IF(profile_id = pr_profile_id, true, false)
        WHERE
			account_id = profile_get_account_id(pr_profile_id) AND
            profile_id > 0; -- Чтобы не выключать SafeMode
        
		SELECT
			'Профиль успешно выбран' AS message,
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
    
    IF pr_profile_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор профиля' AS message,
            false AS is_valid;
    ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанного профиля не существует' AS message,
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
    
    IF pr_profile_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор профиля' AS message,
            false AS is_valid;
    ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанного профиля не существует' AS message,
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
    
    IF pr_profile_id IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор профиля' AS message,
            false AS is_valid;
    ELSEIF NOT profile_is_exists(pr_profile_id) THEN
		ROLLBACK;
		SELECT
			'Указанного профиля не существует' AS message,
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

CREATE PROCEDURE profile_subscribe_invite_delete(pr_profile_subscribe_invite_id BIGINT UNSIGNED)
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

CREATE PROCEDURE profile_subscribe(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED,
    IN pr_profile_subscribe_invite_id BIGINT UNSIGNED
)
BEGIN
	DECLARE pr_is_accept_status BOOLEAN;

	START TRANSACTION;
    
    IF pr_profile_at IS NULL OR pr_profile_to IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор для обоих профилей: кто и на кого подписывается' AS message,
            false AS is_valid;
	ELSEIF NOT profile_is_exists(pr_profile_at) THEN
		ROLLBACK;
		SELECT
			'Подписчика с указанным идентификатором не существует' AS message,
			false AS is_valid;
	ELSEIF NOT profile_is_exists(pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Профиля с указанным идентификатором не существует' AS message,
			false AS is_valid;
	ELSEIF pr_profile_at = pr_profile_to THEN
		ROLLBACK;
		SELECT
			'Подписка на себя не допустима' AS message,
			false AS is_valid;
	ELSEIF pr_profile_subscribe_invite_id IS NOT NULL AND NOT profile_is_owner_subscribe_invite(pr_profile_to, pr_profile_subscribe_invite_id) THEN
		ROLLBACK;
		SELECT
			'Указанный профиль не является владельцем данной ссылки' AS message,
			false AS is_valid;
	ELSEIF profile_is_subscribe_to(pr_profile_at, pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Запрос на подписку этому профилю уже был отправлен' AS message,
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

CREATE PROCEDURE profile_unsubscribe(
	IN pr_profile_at BIGINT UNSIGNED,
    IN pr_profile_to BIGINT UNSIGNED
)
BEGIN
	START TRANSACTION;
    
    IF pr_profile_at IS NULL OR pr_profile_to IS NULL THEN
		ROLLBACK;
		SELECT
			'Необходимо указать идентификатор для обоих профилей: кто и от кого отписывается' AS message,
            false AS is_valid;
	ELSEIF NOT profile_is_exists(pr_profile_at) THEN
		ROLLBACK;
		SELECT
			'Подписчика с указанным идентификатором не существует' AS message,
			false AS is_valid;
	ELSEIF NOT profile_is_exists(pr_profile_to) THEN
		ROLLBACK;
		SELECT
			'Профиля с указанным идентификатором не существует' AS message,
			false AS is_valid;
	ELSEIF NOT profile_is_subscribe_to(pr_profile_at, pr_profile_to) THEN
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







DELIMITER ;

-- TODO:
/*
- При отключении просмотров у профиля удалять их все
- В целом добавить методы для включения и отключения просмотров у профиля
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