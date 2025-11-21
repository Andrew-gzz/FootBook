-- =====================================================
--  SCHEMA
-- =====================================================
CREATE DATABASE IF NOT EXISTS footbook_db
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE footbook_db;

-- =====================================================
--  TABLES
-- =====================================================

CREATE TABLE categories (
  id      INT NOT NULL AUTO_INCREMENT,
  name    VARCHAR(32)  NOT NULL,
  status  TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE users (
  id            BIGINT NOT NULL AUTO_INCREMENT,
  admin         TINYINT(1) NOT NULL,
  username      VARCHAR(32)  NOT NULL,
  email         VARCHAR(64)  NOT NULL,
  password      VARCHAR(255) NOT NULL,
  fullname      VARCHAR(255) NOT NULL,
  birthday      DATE NOT NULL,
  gender        INT NOT NULL,
  birth_country VARCHAR(32)  NOT NULL,
  country       VARCHAR(32)  NOT NULL,
  avatar        LONGBLOB,
  status        TINYINT(1)   NOT NULL DEFAULT 1,
  created_at    TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY username (username),
  UNIQUE KEY email    (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE worldcups (
  id          INT NOT NULL AUTO_INCREMENT,
  name        VARCHAR(64)  NOT NULL,
  country     VARCHAR(32)  NOT NULL,
  year        INT          NOT NULL,
  description TEXT,
  banner      LONGBLOB,
  status      TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE posts (
  id          BIGINT NOT NULL AUTO_INCREMENT,
  user_id     BIGINT NOT NULL,
  category_id INT    NOT NULL,
  worldcup_id INT    NOT NULL,
  title       VARCHAR(64)  NOT NULL,
  team        VARCHAR(32)  DEFAULT NULL,
  description TEXT         NOT NULL,
  media       LONGBLOB,
  views       INT DEFAULT NULL,
  approved    TINYINT(1) DEFAULT NULL,
  status      TINYINT(1) NOT NULL DEFAULT 1,
  created_at  TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  approved_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY user_id     (user_id),
  KEY category_id (category_id),
  KEY worldcup_id (worldcup_id),
  CONSTRAINT posts_ibfk_1 FOREIGN KEY (user_id)     REFERENCES users     (id),
  CONSTRAINT posts_ibfk_2 FOREIGN KEY (category_id) REFERENCES categories(id),
  CONSTRAINT posts_ibfk_3 FOREIGN KEY (worldcup_id) REFERENCES worldcups (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE comments (
  id         BIGINT NOT NULL AUTO_INCREMENT,
  post_id    BIGINT NOT NULL,
  user_id    BIGINT NOT NULL,
  content    TEXT   NOT NULL,
  status     TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY post_id (post_id),
  KEY user_id (user_id),
  CONSTRAINT comments_ibfk_1 FOREIGN KEY (post_id) REFERENCES posts (id),
  CONSTRAINT comments_ibfk_2 FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE postlikes (
  id         BIGINT NOT NULL AUTO_INCREMENT,
  user_id    BIGINT NOT NULL,
  post_id    BIGINT NOT NULL,
  status     TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY post_user_unique (post_id, user_id),
  KEY user_id (user_id),
  CONSTRAINT postlikes_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT postlikes_ibfk_2 FOREIGN KEY (post_id) REFERENCES posts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE commentlikes (
  id         BIGINT NOT NULL AUTO_INCREMENT,
  user_id    BIGINT NOT NULL,
  comment_id BIGINT NOT NULL,
  status     TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY comment_user_unique (comment_id, user_id),
  KEY user_id (user_id),
  CONSTRAINT commentlikes_ibfk_1 FOREIGN KEY (user_id)    REFERENCES users    (id),
  CONSTRAINT commentlikes_ibfk_2 FOREIGN KEY (comment_id) REFERENCES comments (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
--  FUNCTIONS
-- =====================================================
DELIMITER //

CREATE FUNCTION fn_exists_post_active(p_post_id BIGINT)
RETURNS TINYINT
READS SQL DATA
DETERMINISTIC
BEGIN
  RETURN EXISTS(
    SELECT 1
    FROM posts
    WHERE id = p_post_id AND status = 1
  );
END;
//

CREATE FUNCTION fn_exists_user_active(p_user_id BIGINT)
RETURNS TINYINT
READS SQL DATA
DETERMINISTIC
BEGIN
  RETURN EXISTS(
    SELECT 1
    FROM Users
    WHERE id = p_user_id AND status = 1
  );
END;
//

DELIMITER ;

-- =====================================================
--  STORED PROCEDURES
-- =====================================================
DELIMITER //

CREATE PROCEDURE sp_approve_post(
    IN p_post_id     BIGINT,
    IN p_is_approved TINYINT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    IF p_post_id IS NULL OR p_post_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_post_id inválido';
    END IF;

    IF p_is_approved NOT IN (0,1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_is_approved debe ser 0 o 1';
    END IF;

    SELECT COUNT(*) INTO v_exists
      FROM posts
     WHERE id = p_post_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El post no existe';
    END IF;

    START TRANSACTION;

    UPDATE posts
       SET approved    = p_is_approved,
           approved_at = CASE WHEN p_is_approved = 1 THEN CURRENT_TIMESTAMP() ELSE NULL END
     WHERE id = p_post_id;

    SELECT id, approved, approved_at
      FROM posts
     WHERE id = p_post_id;

    COMMIT;
END;
//

CREATE PROCEDURE sp_category_update(
    IN p_category_id INT,
    IN p_new_name    VARCHAR(32)
)
BEGIN
    DECLARE v_newname VARCHAR(32);

    SET v_newname = TRIM(p_new_name);

    IF p_category_id IS NULL OR p_category_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'id de categoría inválido';
    END IF;

    IF v_newname IS NULL OR CHAR_LENGTH(v_newname) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre es requerido';
    END IF;

    IF CHAR_LENGTH(v_newname) > 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre excede 32 caracteres';
    END IF;

    IF EXISTS(
        SELECT 1 FROM categories c
        WHERE c.name = v_newname AND c.id <> p_category_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe una categoría con ese nombre';
    END IF;

    START TRANSACTION;

    UPDATE categories
       SET name = v_newname
     WHERE id   = p_category_id;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se actualizó la categoría (id inexistente o sin cambios)';
    END IF;

    SELECT id, name
      FROM categories
     WHERE id = p_category_id;

    COMMIT;
END;
//

CREATE PROCEDURE sp_create_category(
    IN p_name VARCHAR(255)
)
BEGIN
    DECLARE v_name   VARCHAR(255);
    DECLARE v_exists INT DEFAULT 0;

    SET v_name = TRIM(p_name);

    IF v_name IS NULL OR v_name = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre de la categoría es requerido';
    END IF;

    IF CHAR_LENGTH(v_name) > 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre excede 32 caracteres (máx 32)';
    END IF;

    SELECT COUNT(*) INTO v_exists
      FROM categories
     WHERE LOWER(name) = LOWER(v_name);

    IF v_exists > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría ya existe';
    END IF;

    INSERT INTO categories (name)
    VALUES (v_name);

    SELECT LAST_INSERT_ID() AS category_id;
END;
//

CREATE PROCEDURE sp_create_comment(
  IN p_post_id BIGINT,
  IN p_user_id BIGINT,
  IN p_content TEXT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_post_id IS NULL OR p_post_id <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_post_id inválido';
  END IF;

  IF p_user_id IS NULL OR p_user_id <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_user_id inválido';
  END IF;

  IF fn_exists_user_active(p_user_id) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o está inactivo';
  END IF;

  IF fn_exists_post_active(p_post_id) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El post no existe o está inactivo';
  END IF;

  IF p_content IS NULL OR CHAR_LENGTH(TRIM(p_content)) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contenido vacío';
  END IF;

  START TRANSACTION;

  INSERT INTO comments (post_id, user_id, content, status, created_at)
  VALUES (p_post_id, p_user_id, TRIM(p_content), 1, CURRENT_TIMESTAMP);

  SELECT c.id, c.post_id, c.user_id, c.content, c.status, c.created_at
    FROM comments c
   WHERE c.id = LAST_INSERT_ID();

  COMMIT;
END;
//

CREATE PROCEDURE sp_create_post(
    IN p_user_id     BIGINT,
    IN p_category_id INT,
    IN p_worldcup_id INT,
    IN p_team        VARCHAR(32),
    IN p_title       VARCHAR(64),
    IN p_description TEXT,
    IN p_media       LONGBLOB
)
BEGIN
    DECLARE v_user INT DEFAULT 0;
    DECLARE v_cat  INT DEFAULT 0;
    DECLARE v_wc   INT DEFAULT 0;

    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_user_id es requerido';
    END IF;
    IF p_category_id IS NULL OR p_category_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_category_id es requerido';
    END IF;
    IF p_worldcup_id IS NULL OR p_worldcup_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_worldcup_id es requerido';
    END IF;
    IF p_description IS NULL OR CHAR_LENGTH(TRIM(p_description)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_description es requerido';
    END IF;
    IF p_title IS NULL OR CHAR_LENGTH(TRIM(p_title)) = 0
       OR CHAR_LENGTH(TRIM(p_title)) > 64 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'campo p_title invalido';
    END IF;

    SELECT COUNT(*) INTO v_user
      FROM Users
     WHERE id = p_user_id AND status = 1;
    IF v_user = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o está inactivo';
    END IF;

    SELECT COUNT(*) INTO v_cat
      FROM categories
     WHERE id = p_category_id;
    IF v_cat = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe';
    END IF;

    SELECT COUNT(*) INTO v_wc
      FROM worldcups
     WHERE id = p_worldcup_id;
    IF v_wc = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El mundial (worldcup) no existe';
    END IF;

    IF p_team IS NOT NULL AND CHAR_LENGTH(p_team) > 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El campo team excede 32 caracteres';
    END IF;

    START TRANSACTION;

    INSERT INTO posts(
        user_id, category_id, worldcup_id,
        team, title, description, media,
        approved, status, created_at
    )
    VALUES(
        p_user_id, p_category_id, p_worldcup_id,
        p_team, p_title, p_description, p_media,
        0, 1, CURRENT_TIMESTAMP()
    );

    SELECT LAST_INSERT_ID() AS post_id;

    COMMIT;
END;
//

CREATE PROCEDURE sp_create_user(
    IN p_admin TINYINT(1),
    IN p_username VARCHAR(32),
    IN p_email VARCHAR(64),
    IN p_password VARCHAR(255),
    IN p_fullname VARCHAR(255),
    IN p_birthday DATE,
    IN p_gender INT,
    IN p_birth_country VARCHAR(32),
    IN p_country VARCHAR(32),
    IN p_avatar LONGBLOB
)
BEGIN
    INSERT INTO Users (
        admin, username, email, password, fullname, birthday, gender,
        birth_country, country, avatar, status, created_at
    )
    VALUES (
        p_admin, p_username, p_email, p_password, p_fullname, p_birthday, p_gender,
        p_birth_country, p_country, p_avatar, 1, CURRENT_TIMESTAMP
    );
END;
//

CREATE PROCEDURE sp_create_worldcup(
    IN p_name        VARCHAR(64),
    IN p_country     VARCHAR(32),
    IN p_year        INT,
    IN p_description TEXT,
    IN p_banner      LONGBLOB,
    IN p_status      TINYINT(1)
)
BEGIN
    INSERT INTO WorldCups (name, country, year, description, banner, status)
    VALUES (p_name, p_country, p_year, p_description, p_banner, p_status);
END;
//

CREATE PROCEDURE sp_delete_category(IN p_id INT)
BEGIN
    DECLARE v_exists      INT DEFAULT 0;
    DECLARE v_posts_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists
      FROM categories
     WHERE id = p_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe';
    END IF;

    SELECT COUNT(*) INTO v_posts_count
      FROM posts
     WHERE category_id = p_id
       AND status = 1;

    IF v_posts_count > 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'No se puede eliminar: hay publicaciones asociadas a esta categoría';
    END IF;

    UPDATE categories
       SET status = 0
     WHERE id = p_id;

    SELECT id, name, status
      FROM categories
     WHERE id = p_id;
END;
//

CREATE PROCEDURE sp_get_feed(
    IN p_user_id     BIGINT,
    IN p_after_id    BIGINT,
    IN p_limit       INT,
    IN p_category_id INT,
    IN p_worldcup_id INT,
    IN p_order       VARCHAR(32),
    IN p_search_text VARCHAR(255)
)
BEGIN
    IF p_limit IS NULL OR p_limit <= 0 THEN
        SET p_limit = 10;
    END IF;

    IF p_order IS NULL OR p_order = '' THEN
        SET p_order = 'cronologico';
    END IF;

    SET p_search_text = TRIM(COALESCE(p_search_text, ''));

    SELECT 
        p.id, p.title, p.team, p.description, p.created_at, p.approved_at,
        u.id AS user_id, u.username, TO_BASE64(u.avatar) AS avatar_b64,
        c.id AS category_id, c.name AS category_name,
        w.id AS worldcup_id, w.name AS worldcup_name, w.year AS worldcup_year,
        TO_BASE64(p.media) AS media_b64,
        (SELECT COUNT(*) FROM PostLikes pl WHERE pl.post_id = p.id AND pl.status = 1) AS likes_count,
        (SELECT COUNT(*) FROM Comments  co WHERE co.post_id = p.id AND co.status = 1) AS comments_count,
        CASE 
            WHEN p_user_id IS NULL OR p_user_id = 0 THEN 0
            ELSE EXISTS(
                SELECT 1 FROM PostLikes x 
                WHERE x.post_id = p.id AND x.user_id = p_user_id AND x.status = 1
            )
        END AS liked_by_me
    FROM Posts p
    JOIN Users      u ON u.id = p.user_id     AND u.status = 1
    JOIN Categories c ON c.id = p.category_id AND c.status = 1
    JOIN WorldCups  w ON w.id = p.worldcup_id AND w.status = 1
    WHERE p.status = 1 
      AND p.approved = 1
      AND (p_after_id    IS NULL OR p_after_id    = 0 OR p.id < p_after_id)
      AND (p_category_id IS NULL OR p_category_id = 0 OR p.category_id = p_category_id)
      AND (p_worldcup_id IS NULL OR p_worldcup_id = 0 OR p.worldcup_id = p_worldcup_id)
      AND (p_user_id     IS NULL OR p_user_id     = 0 OR p.user_id = p_user_id)
      AND (
        p_search_text = '' 
        OR p.title       LIKE CONCAT('%', p_search_text, '%')
        OR p.description LIKE CONCAT('%', p_search_text, '%')
        OR p.team        LIKE CONCAT('%', p_search_text, '%')
        OR u.username    LIKE CONCAT('%', p_search_text, '%')
        OR c.name        LIKE CONCAT('%', p_search_text, '%')
        OR w.name        LIKE CONCAT('%', p_search_text, '%')
      )
    ORDER BY 
        CASE 
            WHEN p_order = 'cronologico' THEN p.id
            WHEN p_order = 'likes'       THEN likes_count
            WHEN p_order = 'comentarios' THEN comments_count
        END DESC,
        CASE WHEN p_order = 'pais' THEN w.country END ASC,
        p.id DESC
    LIMIT p_limit;
END;
//

CREATE PROCEDURE sp_get_user_for_login(IN p_identity VARCHAR(64))
BEGIN
    SELECT 
        id, admin, username, email, password, fullname, birthday, gender,
        birth_country, country, status, created_at
    FROM Users
    WHERE username = p_identity
      AND status = 1
    LIMIT 1;
END;
//

CREATE PROCEDURE sp_soft_delete_category(IN p_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_id inválido';
    END IF;

    SELECT COUNT(*) INTO v_exists
      FROM categories
     WHERE id = p_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe';
    END IF;

    UPDATE categories
       SET status = 0
     WHERE id = p_id
       AND status <> 0;

    SELECT id, name, status
      FROM categories
     WHERE id = p_id;
END;
//

CREATE PROCEDURE sp_soft_delete_user(IN p_user_id BIGINT)
BEGIN
  DECLARE v_exists INT DEFAULT 0;

  IF p_user_id IS NULL OR p_user_id <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_user_id inválido';
  END IF;

  SELECT COUNT(*) INTO v_exists
    FROM Users
   WHERE id = p_user_id AND status = 1;

  IF v_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no encontrado o ya inactivo';
  END IF;

  START TRANSACTION;

    UPDATE Users
       SET status = 0
     WHERE id = p_user_id
       AND status = 1;

    IF ROW_COUNT() = 0 THEN
      ROLLBACK;
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se actualizó el usuario (ya estaba inactivo)';
    END IF;

  COMMIT;

  SELECT p_user_id AS user_id, 0 AS new_status,
         'Usuario dado de baja (soft delete)' AS message;
END;
//

CREATE PROCEDURE sp_soft_delete_worldcup(IN p_id INT)
BEGIN
    UPDATE WorldCups
       SET status = 0
     WHERE id = p_id;
END;
//

CREATE PROCEDURE sp_toggle_post_like(
    IN p_user_id BIGINT,
    IN p_post_id BIGINT
)
BEGIN
    DECLARE v_post_exists   INT DEFAULT 0;
    DECLARE v_user_exists   INT DEFAULT 0;
    DECLARE v_like_id       BIGINT;
    DECLARE v_current_status TINYINT;

    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'user_id inválido';
    END IF;
    IF p_post_id IS NULL OR p_post_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'post_id inválido';
    END IF;

    SELECT COUNT(*) INTO v_post_exists
      FROM posts
     WHERE id = p_post_id AND status = 1 AND approved = 1;

    IF v_post_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El post no existe o está inactivo';
    END IF;

    SELECT COUNT(*) INTO v_user_exists
      FROM users
     WHERE id = p_user_id AND status = 1;

    IF v_user_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe o está inactivo';
    END IF;

    START TRANSACTION;

    SELECT id, status INTO v_like_id, v_current_status
      FROM postlikes
     WHERE user_id = p_user_id 
       AND post_id = p_post_id
     LIMIT 1;

    IF v_like_id IS NOT NULL THEN
        UPDATE postlikes
           SET status = CASE WHEN status = 1 THEN 0 ELSE 1 END
         WHERE id = v_like_id;

        SELECT 
            id, user_id, post_id, status, created_at,
            (SELECT COUNT(*) FROM postlikes
              WHERE post_id = p_post_id AND status = 1) AS total_likes
        FROM postlikes
        WHERE id = v_like_id;
    ELSE
        INSERT INTO postlikes (user_id, post_id, status, created_at)
        VALUES (p_user_id, p_post_id, 1, CURRENT_TIMESTAMP);

        SET v_like_id = LAST_INSERT_ID();

        SELECT 
            id, user_id, post_id, status, created_at,
            (SELECT COUNT(*) FROM postlikes
              WHERE post_id = p_post_id AND status = 1) AS total_likes
        FROM postlikes
        WHERE id = v_like_id;
    END IF;

    COMMIT;
END;
//

CREATE PROCEDURE sp_update_category(
    IN p_id   INT,
    IN p_name VARCHAR(32)
)
BEGIN
    DECLARE v_name   VARCHAR(32);
    DECLARE v_exists INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists
      FROM categories
     WHERE id = p_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe';
    END IF;

    SET v_name = TRIM(p_name);

    IF v_name IS NULL OR v_name = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre de la categoría es requerido';
    END IF;

    IF CHAR_LENGTH(v_name) > 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre excede 32 caracteres';
    END IF;

    SELECT COUNT(*) INTO v_exists
      FROM categories
     WHERE LOWER(name) = LOWER(v_name)
       AND id <> p_id;

    IF v_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Ya existe otra categoría con ese nombre';
    END IF;

    UPDATE categories
       SET name = v_name
     WHERE id = p_id;

    SELECT id, name
      FROM categories
     WHERE id = p_id;
END;
//

CREATE PROCEDURE sp_update_user_profile(
    IN p_id           BIGINT,
    IN p_fullname     VARCHAR(255),
    IN p_username     VARCHAR(32),
    IN p_email        VARCHAR(64),
    IN p_birthday     DATE,
    IN p_gender       INT,
    IN p_birth_country VARCHAR(32),
    IN p_country      VARCHAR(32),
    IN p_avatar       LONGBLOB,
    IN p_password     VARCHAR(255)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists
      FROM Users
     WHERE id = p_id AND status = 1;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no encontrado';
    END IF;

    UPDATE Users
       SET fullname      = COALESCE(p_fullname, fullname),
           username      = COALESCE(p_username, username),
           email         = COALESCE(p_email, email),
           birthday      = COALESCE(p_birthday, birthday),
           gender        = COALESCE(p_gender, gender),
           birth_country = COALESCE(p_birth_country, birth_country),
           country       = COALESCE(p_country, country),
           avatar        = COALESCE(p_avatar, avatar),
           password      = COALESCE(p_password, password)
     WHERE id = p_id;

    SELECT 
        id, username, email, fullname,
        'Perfil actualizado correctamente' AS message
    FROM Users
    WHERE id = p_id;
END;
//

CREATE PROCEDURE sp_update_worldcup(
    IN p_id          INT,
    IN p_name        VARCHAR(64),
    IN p_country     VARCHAR(32),
    IN p_year        INT,
    IN p_description TEXT,
    IN p_banner      LONGBLOB,
    IN p_status      TINYINT(1)
)
BEGIN
    UPDATE WorldCups
       SET name        = p_name,
           country     = p_country,
           year        = p_year,
           description = p_description,
           banner      = p_banner,
           status      = p_status
     WHERE id = p_id;
END;
//

DELIMITER ;

-- =====================================================
--  VIEWS
-- =====================================================

CREATE OR REPLACE VIEW v_lista_de_categorias AS
SELECT id, name, status
  FROM categories;

CREATE OR REPLACE VIEW v_lista_de_comentarios AS
SELECT c.id,
       c.post_id,
       c.user_id,
       u.username,
       CASE WHEN u.avatar IS NULL THEN NULL ELSE TO_BASE64(u.avatar) END AS avatar_b64,
       c.content,
       c.status,
       c.created_at
  FROM comments c
  LEFT JOIN users u ON u.id = c.user_id;

CREATE OR REPLACE VIEW v_lista_de_mundiales AS
SELECT w.id,
       w.name,
       w.country,
       w.year,
       w.description,
       TO_BASE64(w.banner) AS banner_b64,
       w.status
  FROM worldcups w;

CREATE OR REPLACE VIEW v_lista_de_usuarios AS
SELECT u.id,
       u.admin,
       u.username,
       u.email,
       u.fullname,
       u.birthday,
       u.gender,
       u.birth_country,
       u.country,
       u.status,
       u.created_at,
       TO_BASE64(u.avatar) AS avatar_b64
  FROM users u;

CREATE OR REPLACE VIEW v_lista_ligera_de_mundiales AS
SELECT id, name, country, year, description, status
  FROM worldcups;

CREATE OR REPLACE VIEW v_lista_ligera_de_publicaciones AS
SELECT p.id,
       u.username,
       c.name AS category_name,
       w.name AS worldcup_name,
       p.title,
       p.description,
       CASE WHEN p.media IS NULL THEN NULL ELSE TO_BASE64(p.media) END AS media_b64,
       p.created_at,
       p.approved,
       p.status
  FROM posts p
  LEFT JOIN users      u ON u.id = p.user_id
  LEFT JOIN categories c ON c.id = p.category_id
  LEFT JOIN worldcups  w ON w.id = p.worldcup_id;

CREATE OR REPLACE VIEW v_lista_ligera_de_usuarios AS
SELECT id, username, email, created_at, status
  FROM users;

-- =====================================================
--  TRIGGERS
-- =====================================================
DELIMITER //

CREATE TRIGGER tr_categories_softdelete_cascade_posts
AFTER UPDATE ON categories
FOR EACH ROW
BEGIN
  IF NEW.status = 0 AND (OLD.status IS NULL OR OLD.status <> 0) THEN
    UPDATE posts
       SET status = 0
     WHERE category_id = NEW.id
       AND status = 1;
  END IF;
END;
//

CREATE TRIGGER tr_posts_softdelete_cascade_comments
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
  IF NEW.status = 0 AND (OLD.status IS NULL OR OLD.status <> 0) THEN
    UPDATE comments
       SET status = 0
     WHERE post_id = NEW.id
       AND status = 1;
  END IF;
END;
//

CREATE TRIGGER tr_users_softdelete_cascade
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
  IF NEW.status = 0 AND (OLD.status IS NULL OR OLD.status <> 0) THEN
    UPDATE posts
       SET status = 0
     WHERE user_id = NEW.id
       AND status = 1;

    UPDATE comments
       SET status = 0
     WHERE user_id = NEW.id
       AND status = 1;
  END IF;
END;
//

-- Trigger nuevo: baja de mundial -> baja de posts relacionados
CREATE TRIGGER tr_worldcups_softdelete_cascade_posts
AFTER UPDATE ON worldcups
FOR EACH ROW
BEGIN
  IF NEW.status = 0 AND (OLD.status IS NULL OR OLD.status <> 0) THEN
    UPDATE posts
       SET status = 0
     WHERE worldcup_id = NEW.id
       AND status = 1;
  END IF;
END;
//

DELIMITER ;
