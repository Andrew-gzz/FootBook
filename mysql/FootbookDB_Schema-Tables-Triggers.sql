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
