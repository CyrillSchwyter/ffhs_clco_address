CREATE DATABASE clco_uebung;
USE clco_uebung;

CREATE TABLE `address` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `plz` varchar(255) DEFAULT NULL,
  `stadt` varchar(255) DEFAULT NULL,
  `strasse` varchar(255) DEFAULT NULL,
  `vorname` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) CHARSET=UTF8;