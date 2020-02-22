CREATE DATABASE IF NOT EXISTS practicafinal;

USE practicafinal;


-- Esto usa Mysql 8, compatibilidad previa no garantizada
-- Los drops para descomentarlos y así altero algo que me da pereza escribir alter
-- DROP TABLE IF EXISTS tipo;
CREATE TABLE IF NOT EXISTS tipo
( -- Almacena 1 como interna, y 2 como externa
	id_tipo     TINYINT AUTO_INCREMENT,
	nombre_tipo VARCHAR(8) NOT NULL,

	PRIMARY KEY (id_tipo)
);

-- DROP TABLE IF EXISTS sexo;
CREATE TABLE IF NOT EXISTS sexo
( -- Almacena 1 como masculino y 2 como femenino
	id_sexo TINYINT AUTO_INCREMENT,
	nombre  VARCHAR(9),

	PRIMARY KEY (id_sexo)
);

-- DROP TABLE IF EXISTS escuela;
CREATE TABLE IF NOT EXISTS escuela
(
	id_escuela     INT AUTO_INCREMENT,
	nombre_escuela VARCHAR(255) NOT NULL,

	PRIMARY KEY (id_escuela)
);

-- DROP TABLE IF EXISTS universidad;
CREATE TABLE IF NOT EXISTS universidad
(
	id_universidad     INT AUTO_INCREMENT,
	nombre_universidad VARCHAR(300) NOT NULL,

	PRIMARY KEY (id_universidad)
);

-- DROP TABLE IF EXISTS bases;
CREATE TABLE IF NOT EXISTS bases
(
	id_bases          INT AUTO_INCREMENT,
	objetivos         VARCHAR(400) NOT NULL,
	quienes_postulan  VARCHAR(400) NOT NULL, -- TODO llevar a una tabla
	herramientas      VARCHAR(200) NOT NULL, -- TODO llevar a una tabla
	cantidad_x_equipo INT          NOT NULL,
	nombre_archivo    VARCHAR(255) NOT NULL, -- Limite del largo de un nombre en NTFS.
	path_archivo      VARCHAR(260) NOT NULL, -- Limite de un PATH en windows hasta windows 10 versión 1607

	PRIMARY KEY (id_bases)
);

-- DROP TABLE IF EXISTS concurso;
CREATE TABLE IF NOT EXISTS concurso
(
	id_concurso          INT AUTO_INCREMENT,
	nombre               VARCHAR(50) NOT NULL,
	apertura_inscripcion DATE        NOT NULL,
	cierre_inscripcion   DATE        NOT NULL,
	fecha                DATE        NOT NULL,
	tipo_fk              TINYINT     NOT NULL, -- Apunta a la tabla tipo
	bases_fk             INT         NOT NULL, -- Apunta a la tabla bases


	PRIMARY KEY (id_concurso),
	FOREIGN KEY (tipo_fk)
		REFERENCES tipo (id_tipo),
	FOREIGN KEY (bases_fk)
		REFERENCES bases (id_bases),

	CONSTRAINT apertura_antes_evento CHECK ( apertura_inscripcion < fecha ),
	CONSTRAINT cierre_despues_apertura CHECK ( cierre_inscripcion > apertura_inscripcion ),
	CONSTRAINT cierre_despues_evento CHECK ( cierre_inscripcion <= fecha )
	-- CONSTRAINT fecha_antes_ahora CHECK ( CURDATE() > fecha ) No es posible hacer en un constrint :(

);

-- DROP TABLE IF EXISTS equipo;
CREATE TABLE IF NOT EXISTS equipo
(
	id_equipo         INT AUTO_INCREMENT,
	nombre            VARCHAR(50) NOT NULL,
	fecha_inscripcion DATE        NOT NULL,
	concurso_fk       INT         NOT NULL,

	PRIMARY KEY (id_equipo),
	FOREIGN KEY (concurso_fk)
		REFERENCES concurso (id_concurso)
);

-- DROP TABLE IF EXISTS participante;
CREATE TABLE IF NOT EXISTS participante
(
	id_participante INT AUTO_INCREMENT,
	nombre          VARCHAR(40) NOT NULL,
	apellido        VARCHAR(40) NOT NULL,
	dni             INT         NOT NULL CHECK (dni BETWEEN 10000000 AND 99999999),
	codigo          VARCHAR(20) NOT NULL,
	sexo_fk         TINYINT     NOT NULL,
	escuela_fk      INT         NOT NULL,
	ciclo           TINYINT     NOT NULL CHECK ( ciclo BETWEEN 1 AND 16), -- Por medicas el 16
	universidad_fk  INT,                                                  -- Puede ser null, en caso de ser interna

	PRIMARY KEY (id_participante),
	FOREIGN KEY (escuela_fk)
		REFERENCES escuela (id_escuela),
	FOREIGN KEY (universidad_fk)
		REFERENCES universidad (id_universidad),
	FOREIGN KEY (sexo_fk)
		REFERENCES sexo (id_sexo)
);

-- DROP TABLE IF EXISTS equipo_participante;
CREATE TABLE IF NOT EXISTS equipo_participante
(
	id_equipo_participante BIGINT AUTO_INCREMENT,
	participante_fk        INT NOT NULL,
	equipo_fk              INT NOT NULL,

	PRIMARY KEY (id_equipo_participante),
	FOREIGN KEY (participante_fk)
		REFERENCES participante (id_participante),
	FOREIGN KEY (equipo_fk)
		REFERENCES equipo (id_equipo)
);

INSERT INTO
	tipo (nombre_tipo)
VALUES
	('Interno')
  , ('externo');

INSERT INTO
	sexo(nombre)
VALUES
	('Masculino')
  , ('Femenino');


DELIMITER $$

CREATE TRIGGER no_fechas_pasadas
	AFTER INSERT
	ON concurso
	FOR EACH ROW
BEGIN
	DECLARE msg VARCHAR(256) $$
	IF new.fecha < CURRENT_DATE THEN
		SET msg = concat('La fecha del concurso es en el pasado: ', new.fecha) $$
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg $$
	END IF
	$$
END $$

CREATE TRIGGER no_inscripcion_despues_del_cierre
	AFTER INSERT
	ON equipo
	FOR EACH ROW
BEGIN
	DECLARE msg VARCHAR(256) $$
	DECLARE fecha_cierre DATE $$
	SET fecha_cierre = (SELECT (cierre_inscripcion) FROM concurso WHERE id_concurso = new.concurso_fk) $$
	IF new.fecha_inscripcion > fecha_cierre
	THEN
		SET msg = concat('La fecha de inscripcion ya paso: ', fecha_cierre) $$
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg $$
	END IF
	$$
END $$

DELIMITER ;

DELIMITER //

-- Este deberia hacer la tarea del 3 y 5
CREATE PROCEDURE insertequipo(IN nombre_concurso VARCHAR(50),
                              IN nombre_equipo VARCHAR(50),
                              IN p1_nombre VARCHAR(40),
                              IN p1_apellido VARCHAR(40),
                              IN p1_dni INT,
                              IN p1_codigo VARCHAR(20),
                              IN p1_sexo VARCHAR(10),
                              IN p1_escuela VARCHAR(255),
                              IN p1_ciclo TINYINT,
                              IN p1_universidad VARCHAR(255) -- Universidad puede ser null
)
BEGIN
	DECLARE id_concurso INT//
	DECLARE msg1 VARCHAR(256)//
	DECLARE equipo_id INT//
	SET id_concurso = (SELECT id_concurso FROM concurso WHERE concurso.nombre = nombre_concurso) //
	IF id_concurso IS NULL THEN
		SET msg1 = 'El nombre del concurso es invalido' //
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg1 //
	ELSE
		INSERT INTO equipo(nombre, fecha_inscripcion, concurso_fk) VALUES (nombre_equipo, CURRENT_DATE, id_concurso) //
		SET equipo_id = (SELECT LAST_INSERT_ID()) //
		INSERT INTO
			participante(nombre, apellido, dni, codigo, sexo_fk, escuela_fk, ciclo, universidad_fk)
		VALUES
		( p1_nombre, p1_apellido, p1_dni, p1_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p1_sexo)
		, (SELECT id_escuela FROM escuela WHERE nombre_escuela = p1_escuela), p1_ciclo, p1_universidad) //

	END IF
	 //
END  //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insertequipo(IN nombre_concurso VARCHAR(50),
                              IN nombre_equipo VARCHAR(50),
                              IN p1_nombre VARCHAR(40),
                              IN p1_apellido VARCHAR(40),
                              IN p1_dni INT,
                              IN p1_codigo VARCHAR(20),
                              IN p1_sexo VARCHAR(10),
                              IN p1_escuela VARCHAR(255),
                              IN p1_ciclo TINYINT,
                              IN p1_universidad VARCHAR(255), -- Universidad puede ser null
                              IN p2_nombre VARCHAR(40),
                              IN p2_apellido VARCHAR(40),
                              IN p2_dni INT,
                              IN p2_codigo VARCHAR(20),
                              IN p2_sexo VARCHAR(10),
                              IN p2_escuela VARCHAR(255),
                              IN p2_ciclo TINYINT,
                              IN p2_universidad VARCHAR(255) -- Universidad puede ser null
)
BEGIN
	DECLARE id_concurso INT //
	DECLARE msg VARCHAR(256) //
	DECLARE equipo_id INT //
	SET id_concurso = (SELECT id_concurso FROM concurso WHERE concurso.nombre = nombre_concurso) //
	IF id_concurso IS NULL THEN
		SET msg = 'El nombre del concurso es invalido' //
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg //
	ELSE
		INSERT INTO equipo(nombre, fecha_inscripcion, concurso_fk) VALUES (nombre_equipo, CURRENT_DATE, id_concurso) //
		SET equipo_id = (SELECT LAST_INSERT_ID()) //
		INSERT INTO
			participante(nombre, apellido, dni, codigo, sexo_fk, escuela_fk, ciclo, universidad_fk)
		VALUES
		    ( p1_nombre, p1_apellido, p1_dni, p1_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p1_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p1_escuela), p1_ciclo, p1_universidad)
		  , ( p2_nombre, p2_apellido, p2_dni, p2_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p2_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p2_escuela), p2_ciclo, p2_universidad) //

	END IF
	 //
END  //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insertequipo(IN nombre_concurso VARCHAR(50),
                              IN nombre_equipo VARCHAR(50),
                              IN p1_nombre VARCHAR(40),
                              IN p1_apellido VARCHAR(40),
                              IN p1_dni INT,
                              IN p1_codigo VARCHAR(20),
                              IN p1_sexo VARCHAR(10),
                              IN p1_escuela VARCHAR(255),
                              IN p1_ciclo TINYINT,
                              IN p1_universidad VARCHAR(255),
                              IN p2_nombre VARCHAR(40),
                              IN p2_apellido VARCHAR(40),
                              IN p2_dni INT,
                              IN p2_codigo VARCHAR(20),
                              IN p2_sexo VARCHAR(10),
                              IN p2_escuela VARCHAR(255),
                              IN p2_ciclo TINYINT,
                              IN p2_universidad VARCHAR(255),
                              IN p3_nombre VARCHAR(40),
                              IN p3_apellido VARCHAR(40),
                              IN p3_dni INT,
                              IN p3_codigo VARCHAR(20),
                              IN p3_sexo VARCHAR(10),
                              IN p3_escuela VARCHAR(255),
                              IN p3_ciclo TINYINT,
                              IN p3_universidad VARCHAR(255) -- Universidad puede ser null
)
BEGIN
	DECLARE id_concurso INT //
	DECLARE msg VARCHAR(256) //
	DECLARE equipo_id INT //
	SET id_concurso = (SELECT id_concurso FROM concurso WHERE concurso.nombre = nombre_concurso) //
	IF id_concurso IS NULL THEN
		SET msg = 'El nombre del concurso es invalido' //
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg //
	ELSE
		INSERT INTO equipo(nombre, fecha_inscripcion, concurso_fk) VALUES (nombre_equipo, CURRENT_DATE, id_concurso) //
		SET equipo_id = (SELECT LAST_INSERT_ID()) //
		INSERT INTO
			participante(nombre, apellido, dni, codigo, sexo_fk, escuela_fk, ciclo, universidad_fk)
		VALUES
		    ( p1_nombre, p1_apellido, p1_dni, p1_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p1_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p1_escuela), p1_ciclo, p1_universidad)
		  , ( p2_nombre, p2_apellido, p2_dni, p2_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p2_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p2_escuela), p2_ciclo, p2_universidad)
		  , ( p3_nombre, p3_apellido, p3_dni, p3_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p3_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p3_escuela), p3_ciclo, p3_universidad) //

		SELECT 'Se ingreso los valores correctamente' //
	END IF
	 //
END  //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insertequipo(IN nombre_concurso VARCHAR(50),
                              IN nombre_equipo VARCHAR(50),
                              IN p1_nombre VARCHAR(40),
                              IN p1_apellido VARCHAR(40),
                              IN p1_dni INT,
                              IN p1_codigo VARCHAR(20),
                              IN p1_sexo VARCHAR(10),
                              IN p1_escuela VARCHAR(255),
                              IN p1_ciclo TINYINT,
                              IN p1_universidad VARCHAR(255),
                              IN p2_nombre VARCHAR(40),
                              IN p2_apellido VARCHAR(40),
                              IN p2_dni INT,
                              IN p2_codigo VARCHAR(20),
                              IN p2_sexo VARCHAR(10),
                              IN p2_escuela VARCHAR(255),
                              IN p2_ciclo TINYINT,
                              IN p2_universidad VARCHAR(255),
                              IN p3_nombre VARCHAR(40),
                              IN p3_apellido VARCHAR(40),
                              IN p3_dni INT,
                              IN p3_codigo VARCHAR(20),
                              IN p3_sexo VARCHAR(10),
                              IN p3_escuela VARCHAR(255),
                              IN p3_ciclo TINYINT,
                              IN p3_universidad VARCHAR(255), -- Universidad puede ser null
                              IN p4_nombre VARCHAR(40),
                              IN p4_apellido VARCHAR(40),
                              IN p4_dni INT,
                              IN p4_codigo VARCHAR(20),
                              IN p4_sexo VARCHAR(10),
                              IN p4_escuela VARCHAR(255),
                              IN p4_ciclo TINYINT,
                              IN p4_universidad VARCHAR(255) -- Universidad puede ser null
)
BEGIN
	DECLARE id_concurso INT //
	DECLARE msg VARCHAR(256) //
	DECLARE equipo_id INT //
	SET id_concurso = (SELECT id_concurso FROM concurso WHERE concurso.nombre = nombre_concurso) //
	IF id_concurso IS NULL THEN
		SET msg = 'El nombre del concurso es invalido' //
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg //
	ELSE
		INSERT INTO equipo(nombre, fecha_inscripcion, concurso_fk) VALUES (nombre_equipo, CURRENT_DATE, id_concurso) //
		SET equipo_id = (SELECT LAST_INSERT_ID()) //
		INSERT INTO
			participante(nombre, apellido, dni, codigo, sexo_fk, escuela_fk, ciclo, universidad_fk)
		VALUES
		    ( p1_nombre, p1_apellido, p1_dni, p1_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p1_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p1_escuela), p1_ciclo, p1_universidad)
		  , ( p2_nombre, p2_apellido, p2_dni, p2_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p2_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p2_escuela), p2_ciclo, p2_universidad)
		  , ( p3_nombre, p3_apellido, p3_dni, p3_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p3_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p3_escuela), p3_ciclo, p3_universidad)
		  , ( p4_nombre, p4_apellido, p4_dni, p4_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p4_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p4_escuela), p4_ciclo, p4_universidad) //

		SELECT 'Se ingreso los valores correctamente' //
	END IF
	 //
END  //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insertequipo(IN nombre_concurso VARCHAR(50),
                              IN nombre_equipo VARCHAR(50),
                              IN p1_nombre VARCHAR(40),
                              IN p1_apellido VARCHAR(40),
                              IN p1_dni INT,
                              IN p1_codigo VARCHAR(20),
                              IN p1_sexo VARCHAR(10),
                              IN p1_escuela VARCHAR(255),
                              IN p1_ciclo TINYINT,
                              IN p1_universidad VARCHAR(255),
                              IN p2_nombre VARCHAR(40),
                              IN p2_apellido VARCHAR(40),
                              IN p2_dni INT,
                              IN p2_codigo VARCHAR(20),
                              IN p2_sexo VARCHAR(10),
                              IN p2_escuela VARCHAR(255),
                              IN p2_ciclo TINYINT,
                              IN p2_universidad VARCHAR(255),
                              IN p3_nombre VARCHAR(40),
                              IN p3_apellido VARCHAR(40),
                              IN p3_dni INT,
                              IN p3_codigo VARCHAR(20),
                              IN p3_sexo VARCHAR(10),
                              IN p3_escuela VARCHAR(255),
                              IN p3_ciclo TINYINT,
                              IN p3_universidad VARCHAR(255), -- Universidad puede ser null
                              IN p4_nombre VARCHAR(40),
                              IN p4_apellido VARCHAR(40),
                              IN p4_dni INT,
                              IN p4_codigo VARCHAR(20),
                              IN p4_sexo VARCHAR(10),
                              IN p4_escuela VARCHAR(255),
                              IN p4_ciclo TINYINT,
                              IN p4_universidad VARCHAR(255), -- Universidad puede ser null
                              IN p5_nombre VARCHAR(40),
                              IN p5_apellido VARCHAR(40),
                              IN p5_dni INT,
                              IN p5_codigo VARCHAR(20),
                              IN p5_sexo VARCHAR(10),
                              IN p5_escuela VARCHAR(255),
                              IN p5_ciclo TINYINT,
                              IN p5_universidad VARCHAR(255) -- Universidad puede ser null
)
BEGIN
	DECLARE id_concurso INT //
	DECLARE msg VARCHAR(256) //
	DECLARE equipo_id INT //
	SET id_concurso = (SELECT id_concurso FROM concurso WHERE concurso.nombre = nombre_concurso) //
	IF id_concurso IS NULL THEN
		SET msg = 'El nombre del concurso es invalido' //
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg //
	ELSE
		INSERT INTO equipo(nombre, fecha_inscripcion, concurso_fk) VALUES (nombre_equipo, CURRENT_DATE, id_concurso) //
		SET equipo_id = (SELECT LAST_INSERT_ID()) //
		INSERT INTO
			participante(nombre, apellido, dni, codigo, sexo_fk, escuela_fk, ciclo, universidad_fk)
		VALUES
		    ( p1_nombre, p1_apellido, p1_dni, p1_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p1_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p1_escuela), p1_ciclo, p1_universidad)
		  , ( p2_nombre, p2_apellido, p2_dni, p2_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p2_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p2_escuela), p2_ciclo, p2_universidad)
		  , ( p3_nombre, p3_apellido, p3_dni, p3_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p3_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p3_escuela), p3_ciclo, p3_universidad)
		  , ( p4_nombre, p4_apellido, p4_dni, p4_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p4_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p4_escuela), p4_ciclo, p4_universidad)
		  , ( p5_nombre, p5_apellido, p5_dni, p5_codigo, (SELECT id_sexo FROM sexo WHERE nombre = p5_sexo)
		    , (SELECT id_escuela FROM escuela WHERE nombre_escuela = p5_escuela), p5_ciclo, p5_universidad) //

		SELECT 'Se ingreso los valores correctamente' //
	END IF
	 //
END  //

DELIMITER ;

DELIMITER //

-- El 4
CREATE PROCEDURE cantidaddeequipos(IN nombre_concurso VARCHAR(50))
BEGIN
	DECLARE id_concurso INT //
	DECLARE msg VARCHAR(256) //
	SET id_concurso = (SELECT id_concurso FROM concurso WHERE concurso.nombre = nombre_concurso) //
	IF id_concurso IS NULL THEN
		SET msg = 'El nombre del concurso es invalido' //
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg //
	ELSEIF (SELECT tipo_fk FROM concurso WHERE concurso.id_concurso = id_concurso) =
	       (SELECT id_tipo FROM tipo WHERE nombre_tipo = 'Interno') THEN
		SELECT
			CONCAT('La cantidad de equipos inscritos son :',
			       (SELECT COUNT(*) FROM equipo WHERE equipo.concurso_fk = id_concurso))
		 //
	ELSE
		SET msg = 'El concurso es externo' //
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg //
	END IF
	 //

END  //

DELIMITER ;
