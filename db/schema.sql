DROP TABLE IF EXISTS hakojima;
CREATE TABLE hakojima (
    id varchar(255) NOT NULL,
    value varchar(255),
    primary key(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS islands;
CREATE TABLE islands (
    id int NOT NULL auto_increment,
    name varchar(255) NOT NULL,
    score int,
    prize varchar(255),
    absent int,
    cmt varchar(255),
    password varchar(255),
    money int,
    food int,
    population int,
    area int,
    farm int,
    factory int,
    mountain int,
    primary key(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS history;
CREATE TABLE histories (
    id int NOT NULL auto_increment,
    turn int NOT NULL,
    message varchar(255),
    primary key(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
