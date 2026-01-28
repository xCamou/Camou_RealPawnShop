CREATE TABLE IF NOT EXISTS `pawn_shop` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(60) NOT NULL,
    `type` ENUM('item', 'vehicle') NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `price` INT NOT NULL,
    `expiry` DATETIME NOT NULL,
    `is_public` TINYINT(1) DEFAULT 0
);