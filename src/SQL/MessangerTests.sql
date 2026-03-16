CALL account_create('+7 9001234566', 'Саня', 'Мыхалыч', @new_account_id);
SELECT @new_account_id;

CALL account_delete('+7 9001234566');

CALL account_login(20, 'CentBrowser', @session_id);
SELECT @session_id;

CALL account_logout(21);