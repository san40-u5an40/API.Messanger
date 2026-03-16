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
	DECLARE pr_account_login_id BIGINT UNSIGNED;
    
	SELECT account_login_id INTO pr_account_login_id
    FROM account_login
    WHERE
		account_id = pr_account_id AND
        client_name = CAST(pr_client_name AS BINARY);

	RETURN pr_account_login_id;
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




DELIMITER ;