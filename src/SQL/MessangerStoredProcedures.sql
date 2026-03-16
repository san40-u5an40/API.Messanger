DELIMITER //

CREATE PROCEDURE account_create(
	IN pr_phone VARCHAR(17),
    IN pr_first_name VARCHAR(25),
    IN pr_last_name VARCHAR(25),
    OUT pr_account_id BIGINT UNSIGNED
)
BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		GET DIAGNOSTICS CONDITION 1
        @errno = MYSQL_ERRNO;
    
		ROLLBACK;
		SELECT
			CONCAT('Непредвиденная ошибка: ', @errno) AS message,
			false AS is_valid;
    END;
    
	START TRANSACTION;
    
    IF account_is_exists_by_phone(pr_phone) THEN
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

CREATE PROCEDURE account_delete(
	IN pr_phone VARCHAR(17)
)
BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		GET DIAGNOSTICS CONDITION 1
        @errno = MYSQL_ERRNO;
    
		ROLLBACK;
		SELECT
			CONCAT('Непредвиденная ошибка: ', @errno) AS message,
			false AS is_valid;
    END;

	START TRANSACTION;
    
    IF NOT account_is_exists_by_phone(pr_phone) THEN
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
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		GET DIAGNOSTICS CONDITION 1
        @errno = MYSQL_ERRNO;
    
		ROLLBACK;
		SELECT
			CONCAT('Непредвиденная ошибка: ', @errno) AS message,
			false AS is_valid;
    END;

	START TRANSACTION;
    
    SET pr_account_login_id = account_login_get_id(pr_account_id, pr_client_name);
    IF pr_account_login_id IS NOT NULL THEN
		UPDATE account_login
        SET
			last_visited_at = NOW()
		WHERE account_login_id = pr_account_login_id;
        
		SELECT
			'Данные о входе обновлены' AS message,
            true AS is_valid;
        COMMIT;
	ELSE
		IF account_is_exists_by_id(pr_account_id) THEN
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
			ROLLBACK;
            SELECT
				'Указанного аккаунта не существует' AS message,
				true AS is_valid;
        END IF;
    END IF;    
END//

CREATE PROCEDURE account_logout(IN pr_account_login_id BIGINT UNSIGNED)
BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		GET DIAGNOSTICS CONDITION 1
        @errno = MYSQL_ERRNO;
    
		ROLLBACK;
		SELECT
			CONCAT('Непредвиденная ошибка: ', @errno) AS message,
			false AS is_valid;
    END;

	START TRANSACTION;
    
    IF account_login_is_exists(pr_account_login_id) THEN
		DELETE
		FROM account_login
        WHERE account_login_id = pr_account_login_id;
        
        SELECT
			'Выход осуществлён успешно' AS message,
            true AS is_valid;
        COMMIT;
    ELSE
		ROLLBACK;
		SELECT
			'Указанная информация о сессии не была найдена' AS message,
			false AS is_valid;
    END IF;
END//





DELIMITER ;