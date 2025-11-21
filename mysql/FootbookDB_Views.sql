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
