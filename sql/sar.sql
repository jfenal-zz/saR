-- phpMyAdmin SQL Dump
-- version 3.5.1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Oct 05, 2012 at 10:33 PM
-- Server version: 5.1.61
-- PHP Version: 5.3.3

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `sar`
--

-- --------------------------------------------------------

--
-- Table structure for table `data`
--

DROP TABLE IF EXISTS `data`;
CREATE TABLE IF NOT EXISTS `data` (
  `tstamp` int(11) NOT NULL COMMENT 'since epoch',
  `serverid` int(11) NOT NULL COMMENT 'ref to servers table',
  `dataindex` varchar(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT 'eth0, dev8, etc.',
  `metricid` int(11) NOT NULL,
  `value` float NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

-- --------------------------------------------------------

--
-- Stand-in structure for view `longdata`
--
DROP VIEW IF EXISTS `longdata`;
CREATE TABLE IF NOT EXISTS `longdata` (
`metricname` varchar(20)
,`tstamp` int(11)
,`serverid` int(11)
,`dataindex` varchar(12)
,`metricid` int(11)
,`value` float
);
-- --------------------------------------------------------

--
-- Stand-in structure for view `longdata2`
--
DROP VIEW IF EXISTS `longdata2`;
CREATE TABLE IF NOT EXISTS `longdata2` (
`metricname` varchar(20)
,`tstamp` int(11)
,`servername` varchar(64)
,`serverid` int(11)
,`dataindex` varchar(12)
,`metricid` int(11)
,`value` float
);
-- --------------------------------------------------------

--
-- Table structure for table `metrics`
--

DROP TABLE IF EXISTS `metrics`;
CREATE TABLE IF NOT EXISTS `metrics` (
  `metricid` int(11) NOT NULL AUTO_INCREMENT,
  `metricname` varchar(20) CHARACTER SET latin1 NOT NULL,
  `index` varchar(10) CHARACTER SET latin1 NOT NULL,
  PRIMARY KEY (`metricid`),
  UNIQUE KEY `metricname` (`metricname`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_bin AUTO_INCREMENT=194 ;

-- --------------------------------------------------------

--
-- Table structure for table `servers`
--

DROP TABLE IF EXISTS `servers`;
CREATE TABLE IF NOT EXISTS `servers` (
  `serverid` int(11) NOT NULL AUTO_INCREMENT,
  `servername` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`serverid`),
  UNIQUE KEY `servername` (`servername`)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci AUTO_INCREMENT=5 ;

-- --------------------------------------------------------

--
-- Structure for view `longdata`
--
DROP TABLE IF EXISTS `longdata`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `longdata` AS select `metrics`.`metricname` AS `metricname`,`data`.`tstamp` AS `tstamp`,`data`.`serverid` AS `serverid`,`data`.`dataindex` AS `dataindex`,`data`.`metricid` AS `metricid`,`data`.`value` AS `value` from (`metrics` join `data`) where (`metrics`.`metricid` = `data`.`metricid`);

-- --------------------------------------------------------

--
-- Structure for view `longdata2`
--
DROP TABLE IF EXISTS `longdata2`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `longdata2` AS select `metrics`.`metricname` AS `metricname`,`data`.`tstamp` AS `tstamp`,`servers`.`servername` AS `servername`,`data`.`serverid` AS `serverid`,`data`.`dataindex` AS `dataindex`,`data`.`metricid` AS `metricid`,`data`.`value` AS `value` from ((`metrics` join `data`) join `servers`) where ((`metrics`.`metricid` = `data`.`metricid`) and (`servers`.`serverid` = `data`.`serverid`));

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
