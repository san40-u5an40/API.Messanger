DROP SCHEMA IF EXISTS messanger;
CREATE SCHEMA messanger;
USE messanger;

DROP TABLE IF EXISTS account;
CREATE TABLE IF NOT EXISTS account (
    account_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    phone VARCHAR(17) NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT NOW(),
    first_name VARCHAR(25) NOT NULL,
    last_name VARCHAR(25) NOT NULL
);

-- Аудит сессий
DROP TABLE IF EXISTS account_login;
CREATE TABLE IF NOT EXISTS account_login (
	account_login_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	account_id BIGINT UNSIGNED NOT NULL,
    client_name VARCHAR(100) NOT NULL,
    last_visited_at DATETIME NOT NULL DEFAULT NOW(),
    FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE CASCADE,
    INDEX idx_account_id_client_name(account_id, client_name)
);

-- Для отслеживания подозрительной активности
DROP TABLE IF EXISTS account_deleted_history;
CREATE TABLE IF NOT EXISTS account_deleted_history (
	account_deleted_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	phone VARCHAR(17) NOT NULL,
    report_count INT UNSIGNED NOT NULL,
    deleted_at DATETIME NOT NULL DEFAULT NOW(),
    INDEX idx_phone(phone)
);

-- Общая часть для профиля и группового чата
DROP TABLE IF EXISTS public_info;
CREATE TABLE IF NOT EXISTS public_info (
	public_info_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    created_at DATETIME NOT NULL DEFAULT NOW(),
	name VARCHAR(40) NOT NULL,
    details VARCHAR(100),
    avatar_url TEXT,
    FULLTEXT INDEX idx_name (name)
);

-- На каждом аккаунте может быть не больше 10 профилей
DROP TABLE IF EXISTS profile;
CREATE TABLE IF NOT EXISTS profile (
	profile_id BIGINT UNSIGNED PRIMARY KEY,
	account_id BIGINT UNSIGNED NOT NULL,
    is_last_selected BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    is_can_searched BOOLEAN NOT NULL DEFAULT false, -- Отображение в поисковой выдаче
    is_allow_message_for_non_subscribers BOOLEAN NOT NULL DEFAULT false, -- Могут ли неподписанные профили отправлять сообщение этому профилю
    is_hide_watch BOOLEAN NOT NULL DEFAULT false, -- Скрывает просмотры из статистики
    is_active BOOLEAN NOT NULL DEFAULT true, -- Доступен ли сейчас профиль для отправки сообщений
    FOREIGN KEY (profile_id) REFERENCES public_info (public_info_id) ON DELETE RESTRICT, -- TODO: Проверить не находится ли по этому id групповой чат
    FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE CASCADE,
    INDEX idx_account_id_is_last_selected (account_id, is_last_selected),
    INDEX idx_account_id_is_archived (account_id, is_archived)
);

DROP TABLE IF EXISTS profile_subscribe_invite;
CREATE TABLE IF NOT EXISTS profile_subscribe_invite (
	profile_subscribe_invite_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    profile_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(25) NOT NULL,
    url_value VARCHAR(25) NOT NULL UNIQUE,
    miniature_url TEXT, -- Изображение на предпросмотре ссылки
    inviting_limit INT UNSIGNED,
    is_auto_accept BOOLEAN NOT NULL, -- Автоматическое одобрение подписки
    FOREIGN KEY (profile_id) REFERENCES profile (profile_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS profile_subscribe;
CREATE TABLE IF NOT EXISTS profile_subscribe (
	profile_at BIGINT UNSIGNED NOT NULL,
    profile_to BIGINT UNSIGNED NOT NULL,
    subscribed_at DATETIME NOT NULL DEFAULT NOW(),
    profile_subscribe_invite_id BIGINT UNSIGNED,
    status ENUM('request', 'ignore', 'accept') NOT NULL, -- Статус заявки на подписку
    PRIMARY KEY(profile_at, profile_to),
    FOREIGN KEY (profile_at) REFERENCES profile (profile_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_to) REFERENCES profile (profile_id) ON DELETE CASCADE, -- TODO: Выводить предупреждени о потере подписчиков при удалении профиля
    FOREIGN KEY (profile_subscribe_invite_id) REFERENCES profile_subscribe_invite (profile_subscribe_invite_id) ON DELETE SET NULL,
    INDEX idx_profile_to_status (profile_to, status)
);

DROP TABLE IF EXISTS profile_content_item;
CREATE TABLE IF NOT EXISTS profile_content_item (
	profile_content_item_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	profile_id BIGINT UNSIGNED NOT NULL,
    forwarded_id BIGINT UNSIGNED, -- Рекурсивная ссылка
    value TEXT NOT NULL, -- MarkDown формат
    created_at DATETIME NOT NULL DEFAULT NOW(),
    edited_at DATETIME DEFAULT null,
    FOREIGN KEY (profile_id) REFERENCES profile (profile_id) ON DELETE CASCADE,
    FOREIGN KEY (forwarded_id) REFERENCES profile_content_item (profile_content_item_id) ON DELETE SET NULL
);

DROP TABLE IF EXISTS profile_content_item_report;
CREATE TABLE IF NOT EXISTS profile_content_item_report (
	profile_content_item_report_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    profile_content_item_id BIGINT UNSIGNED,
	profile_id BIGINT UNSIGNED,
    account_id BIGINT UNSIGNED NOT NULL,
    reporter_account_id BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT NOW(),
    details VARCHAR(100),
    FOREIGN KEY (profile_content_item_id) REFERENCES profile_content_item (profile_content_item_id) ON DELETE SET NULL,
    FOREIGN KEY (profile_id) REFERENCES profile (profile_id) ON DELETE SET NULL,
    FOREIGN KEY (account_id) REFERENCES account (account_id) ON DELETE CASCADE,
    FOREIGN KEY (reporter_account_id) REFERENCES account (account_id) ON DELETE CASCADE, -- TODO: Выводить предупреждени о потере жалоб при удалении аккаунта
    INDEX idx_profile_content_item_id_reporter_account_id (profile_content_item_id, reporter_account_id)
);

DROP TABLE IF EXISTS profile_content_item_watch;
CREATE TABLE IF NOT EXISTS profile_content_item_watch (
	profile_content_item_watch_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	profile_content_item_id BIGINT UNSIGNED NOT NULL,
    profile_id BIGINT UNSIGNED NOT NULL,
    watched_at DATETIME NOT NULL DEFAULT NOW(),
    FOREIGN KEY (profile_content_item_id) REFERENCES profile_content_item (profile_content_item_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_id) REFERENCES profile (profile_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS profile_message;
CREATE TABLE IF NOT EXISTS profile_message (
	profile_message_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	profile_content_item_id BIGINT UNSIGNED NOT NULL,
    profile_to BIGINT UNSIGNED NOT NULL, -- Сообщение самому себе — избранное
    is_checked BOOLEAN NOT NULL DEFAULT false,
    FOREIGN KEY (profile_content_item_id) REFERENCES profile_content_item (profile_content_item_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_to) REFERENCES profile (profile_id) ON DELETE CASCADE,
    INDEX idx_profile_to_is_checked (profile_to, is_checked),
    INDEX idx_profile_to_profile_message_id (profile_to, profile_message_id)
);

DROP TABLE IF EXISTS profile_publication;
CREATE TABLE IF NOT EXISTS profile_publication (
	profile_publication_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	profile_content_item_id BIGINT UNSIGNED NOT NULL,
    FOREIGN KEY (profile_content_item_id) REFERENCES profile_content_item (profile_content_item_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS profile_publication_comment;
CREATE TABLE IF NOT EXISTS profile_publication_comment (
	profile_publication_comment_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    profile_publication_id BIGINT UNSIGNED NOT NULL,
    profile_content_item_id BIGINT UNSIGNED NOT NULL,
    FOREIGN KEY (profile_publication_id) REFERENCES profile_publication (profile_publication_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_content_item_id) REFERENCES profile_content_item (profile_content_item_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS profile_group_chat;
CREATE TABLE IF NOT EXISTS profile_group_chat (
	profile_group_chat_id BIGINT UNSIGNED PRIMARY KEY,
    profile_id BIGINT UNSIGNED NOT NULL, -- Владелец
    FOREIGN KEY (profile_group_chat_id) REFERENCES public_info (public_info_id) ON DELETE RESTRICT, -- TODO: Проверить не находится ли по этому id сам профиль
    FOREIGN KEY (profile_id) REFERENCES profile (profile_id) ON DELETE RESTRICT -- При удалении профиля добавить кнопку назначения новых владельцев групповых каналов (иначе передать первому присоединившемуся, а если участников нет, просто удалить)
);

DROP TABLE IF EXISTS profile_group_chat_member;
CREATE TABLE IF NOT EXISTS profile_group_chat_member (
	profile_group_chat_member_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
	profile_group_chat_id BIGINT UNSIGNED NOT NULL,
    profile_id BIGINT UNSIGNED NOT NULL,
    status ENUM('owner', 'moderator', 'member', 'blocked') NOT NULL DEFAULT 'member', -- Модератор имеет те же права, что и владелец (кроме назначения и удаления модерторов) TODO: Проверить уникальность owner'а
    custom_title VARCHAR(20), -- Кличка/роль устанавливаемая админом или модератором
    FOREIGN KEY (profile_group_chat_id) REFERENCES profile_group_chat (profile_group_chat_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_id) REFERENCES profile (profile_id) ON DELETE CASCADE,
    INDEX idx_profile_group_chat_id_profile_id(profile_group_chat_id, profile_id),
    INDEX idx_profile_group_chat_id_status(profile_group_chat_id, status)
);

DROP TABLE IF EXISTS profile_group_chat_message;
CREATE TABLE IF NOT EXISTS profile_group_chat_message (
	profile_group_chat_message_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    profile_content_item_id BIGINT UNSIGNED NOT NULL,
	profile_group_chat_id BIGINT UNSIGNED NOT NULL,
    FOREIGN KEY (profile_content_item_id) REFERENCES profile_content_item (profile_content_item_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_group_chat_id) REFERENCES profile_group_chat (profile_group_chat_id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS profile_publication_checked;
CREATE TABLE IF NOT EXISTS profile_publication_checked (
    profile_at BIGINT UNSIGNED NOT NULL,
    profile_to BIGINT UNSIGNED NOT NULL,
    profile_publication_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY(profile_at, profile_to),
    FOREIGN KEY (profile_at) REFERENCES profile (profile_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_to) REFERENCES profile (profile_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_publication_id) REFERENCES profile_publication (profile_publication_id) ON DELETE NO ACTION
);

DROP TABLE IF EXISTS profile_group_chat_message_checked;
CREATE TABLE IF NOT EXISTS profile_group_chat_message_checked (
	profile_id BIGINT UNSIGNED NOT NULL,
    profile_group_chat_id BIGINT UNSIGNED NOT NULL,
    profile_group_chat_message_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY(profile_id, profile_group_chat_id),
    FOREIGN KEY (profile_id) REFERENCES profile (profile_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_group_chat_id) REFERENCES profile_group_chat (profile_group_chat_id) ON DELETE CASCADE,
    FOREIGN KEY (profile_group_chat_message_id) REFERENCES profile_group_chat_message (profile_group_chat_message_id) ON DELETE NO ACTION
);

-- Эта структура представлена исключительно в учебных целях
-- Реальные проекты основанные на данной логике и реализуемые в РФ нарушали бы пакет Яровой