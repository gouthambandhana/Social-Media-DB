CREATE DATABASE social;
USE social;

CREATE TABLE posts (
  post_id       BIGINT AUTO_INCREMENT PRIMARY KEY,
  author_id     BIGINT NOT NULL,
  content       TEXT NOT NULL,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  like_count    INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  FOREIGN KEY (author_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE comments (
  comment_id    BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id       BIGINT NOT NULL,
  author_id     BIGINT NOT NULL,
  content       TEXT NOT NULL,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users(user_id) ON DELETE CASCADE
);
CREATE TABLE likes (
  post_id    BIGINT NOT NULL,
  user_id    BIGINT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE follows (
  follower_id BIGINT NOT NULL,
  followee_id BIGINT NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_id, followee_id),
  FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
  FOREIGN KEY (followee_id) REFERENCES users(user_id) ON DELETE CASCADE
);

INSERT INTO users (handle, full_name, email, bio) VALUES
('aria', 'Aria Patel', 'aria@example.com', 'Coffee + code.'),
('sam', 'Samuel Roy', 'sam@example.com', 'Runner, reader.'),
('lee', 'Lee Chen', 'lee@example.com', 'Design + data.'),
('noor', 'Noor Khan', 'noor@example.com', 'Film buff.'),
('mia', 'Mia Alvarez', 'mia@example.com', 'Traveler ✈');

INSERT INTO follows VALUES
(1, 2, NOW()), -- aria follows sam
(1, 3, NOW()), -- aria follows lee
(2, 3, NOW()), -- sam follows lee
(2, 4, NOW()), -- sam follows noor
(3, 1, NOW()), -- lee follows aria
(4, 1, NOW()), -- noor follows aria
(5, 1, NOW()); -- mia follows aria
INSERT INTO posts (author_id, content, created_at) VALUES
(1, 'Hello, world! First post 🎉', NOW() - INTERVAL 5 DAY),
(3, 'Designing a minimal UI today.', NOW() - INTERVAL 4 DAY),
(2, '10k run done. Feeling great!', NOW() - INTERVAL 3 DAY),
(4, 'Movie night: recommendations?', NOW() - INTERVAL 2 DAY),
(1, 'SQL window functions are magic.', NOW() - INTERVAL 1 DAY);

INSERT INTO comments (post_id, author_id, content, created_at) VALUES
(1, 3, 'Welcome!', NOW()),
(1, 2, 'Congrats 🎉', NOW()),
(3, 1, 'Nice pace!', NOW()),
(4, 5, 'Try a classic thriller?', NOW());

INSERT INTO likes (post_id, user_id) VALUES
(1, 2), (1, 3), (2, 1),
(3, 1), (3, 3),
(5, 3), (5, 4);

DELIMITER $$

-- Like counter
CREATE TRIGGER t_like_ins AFTER INSERT ON likes
FOR EACH ROW
BEGIN
  UPDATE posts SET like_count = like_count + 1 WHERE post_id = NEW.post_id;
END$$

CREATE TRIGGER t_like_del AFTER DELETE ON likes
FOR EACH ROW
BEGIN
  UPDATE posts SET like_count = like_count - 1 WHERE post_id = OLD.post_id;
END$$

CREATE TRIGGER t_comment_ins AFTER INSERT ON comments
FOR EACH ROW
BEGIN
  UPDATE posts SET comment_count = comment_count + 1 WHERE post_id = NEW.post_id;
END$$


CREATE TRIGGER t_comment_del AFTER DELETE ON comments
FOR EACH ROW
BEGIN
  UPDATE posts SET comment_count = comment_count - 1 WHERE post_id = OLD.post_id;
END$$
DELIMITER ;

-- User stats
CREATE OR REPLACE VIEW v_user_stats AS
SELECT 
  u.user_id,
  u.handle,
  COUNT(DISTINCT p.post_id) AS posts,
  (SELECT COUNT(*) FROM follows f WHERE f.followee_id = u.user_id) AS followers,
  (SELECT COUNT(*) FROM follows f WHERE f.follower_id = u.user_id) AS following,
  COALESCE(SUM(p.like_count),0) AS total_likes_received
FROM users u
LEFT JOIN posts p ON p.author_id = u.user_id
GROUP BY u.user_id, u.handle;

-- Feed view
CREATE OR REPLACE VIEW v_feed AS
SELECT 
  fo.follower_id AS viewer_id,
  p.post_id,
  p.author_id,
  p.content,
  p.created_at,
  p.like_count,
  p.comment_count
FROM follows fo
JOIN posts p ON p.author_id = fo.followee_id
ORDER BY viewer_id, p.created_at DESC;


DELIMITER $$

CREATE PROCEDURE get_feed(IN user_handle VARCHAR(30), IN feed_limit INT)
BEGIN
  SELECT p.post_id, u.handle, p.content, p.created_at, p.like_count, p.comment_count
  FROM posts p
  JOIN follows fo ON fo.followee_id = p.author_id
  JOIN users u ON u.user_id = p.author_id
  WHERE fo.follower_id = (SELECT user_id FROM users WHERE handle = user_handle)
  ORDER BY p.created_at DESC
  LIMIT feed_limit;
END$$
DELIMITER ;

-- 1. All posts by a user
SELECT * FROM posts WHERE author_id = (SELECT user_id FROM users WHERE handle='aria');

- 2. Top 5 most liked posts
SELECT p.post_id, u.handle, p.content, p.like_count
 FROM posts p JOIN users u ON u.user_id = p.author_id
 ORDER BY p.like_count DESC, p.created_at DESC
 LIMIT 5;

-- 3. Leaderboard of followers
 SELECT u.handle, COUNT(f.follower_id) AS followers
 FROM users u LEFT JOIN follows f ON f.followee_id = u.user_id
 GROUP BY u.user_id, u.handle
 ORDER BY followers DESC;

-- 4. View Aria's feed
CALL get_feed('aria', 10);