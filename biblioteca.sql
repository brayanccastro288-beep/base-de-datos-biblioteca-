-- =====================================================================
-- BASE DE DATOS: BIBLIOTECA
-- Motor: MySQL 8.0 (Workbench)
-- Materia: Base de Datos II - Ingeniería de Software - Unicartagena
-- Contenido: 5 tablas, 4 relaciones, funciones (matemáticas y de cadena),
--            triggers y vistas
-- =====================================================================

DROP DATABASE IF EXISTS biblioteca;
CREATE DATABASE biblioteca CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE biblioteca;

-- =====================================================================
-- 1. TABLAS (normalizadas hasta 3FN)
-- =====================================================================

CREATE TABLE categoria (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE autor (
    id_autor     INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(50) NOT NULL,
    apellido     VARCHAR(50) NOT NULL,
    nacionalidad VARCHAR(50)
);

CREATE TABLE libro (
    id_libro               INT AUTO_INCREMENT PRIMARY KEY,
    titulo                 VARCHAR(120) NOT NULL,
    isbn                   VARCHAR(20)  NOT NULL UNIQUE,
    anio_publicacion       INT,
    ejemplares_totales     INT NOT NULL DEFAULT 1,
    ejemplares_disponibles INT NOT NULL DEFAULT 1,
    id_autor               INT NOT NULL,
    id_categoria           INT NOT NULL,
    -- Relación 1: un autor escribe muchos libros
    CONSTRAINT fk_libro_autor FOREIGN KEY (id_autor)
        REFERENCES autor(id_autor),
    -- Relación 2: una categoría agrupa muchos libros
    CONSTRAINT fk_libro_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
);

CREATE TABLE socio (
    id_socio       INT AUTO_INCREMENT PRIMARY KEY,
    cedula         VARCHAR(15) NOT NULL UNIQUE,
    nombre         VARCHAR(50) NOT NULL,
    apellido       VARCHAR(50) NOT NULL,
    correo         VARCHAR(80),
    fecha_registro DATE NOT NULL
);

CREATE TABLE prestamo (
    id_prestamo      INT AUTO_INCREMENT PRIMARY KEY,
    id_libro         INT NOT NULL,
    id_socio         INT NOT NULL,
    fecha_prestamo   DATE NOT NULL,
    fecha_limite     DATE NOT NULL,
    fecha_devolucion DATE NULL,
    multa            DECIMAL(10,2) NOT NULL DEFAULT 0,
    -- Relación 3: un libro puede estar en muchos préstamos
    CONSTRAINT fk_prestamo_libro FOREIGN KEY (id_libro)
        REFERENCES libro(id_libro),
    -- Relación 4: un socio puede hacer muchos préstamos
    CONSTRAINT fk_prestamo_socio FOREIGN KEY (id_socio)
        REFERENCES socio(id_socio)
);

-- =====================================================================
-- 2. FUNCIONES
-- =====================================================================
DELIMITER $$

-- Función de cadena: nombre completo en mayúsculas
CREATE FUNCTION fn_nombre_completo(p_nombre VARCHAR(50), p_apellido VARCHAR(50))
RETURNS VARCHAR(110)
DETERMINISTIC
BEGIN
    RETURN UPPER(CONCAT(TRIM(p_nombre), ' ', TRIM(p_apellido)));
END$$

-- Función de cadena: iniciales de una persona (ej: Gabriel García -> GG)
CREATE FUNCTION fn_iniciales(p_nombre VARCHAR(50), p_apellido VARCHAR(50))
RETURNS VARCHAR(5)
DETERMINISTIC
BEGIN
    RETURN UPPER(CONCAT(LEFT(TRIM(p_nombre), 1), LEFT(TRIM(p_apellido), 1)));
END$$

-- Función matemática: días de retraso (nunca devuelve negativos)
CREATE FUNCTION fn_dias_retraso(p_limite DATE, p_devolucion DATE)
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN GREATEST(DATEDIFF(p_devolucion, p_limite), 0);
END$$

-- Función matemática: multa de $500 por cada día de retraso
CREATE FUNCTION fn_calcular_multa(p_dias INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_dias * 500, 2);
END$$

-- Función matemática: porcentaje de ejemplares disponibles
CREATE FUNCTION fn_porcentaje_disponible(p_disponibles INT, p_totales INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    IF p_totales = 0 THEN
        RETURN 0;
    END IF;
    RETURN ROUND((p_disponibles / p_totales) * 100, 2);
END$$

-- =====================================================================
-- 3. TRIGGERS
-- =====================================================================

-- Antes de prestar: verifica que haya ejemplares disponibles
CREATE TRIGGER trg_prestamo_bi
BEFORE INSERT ON prestamo
FOR EACH ROW
BEGIN
    DECLARE v_disp INT;
    SELECT ejemplares_disponibles INTO v_disp
    FROM libro WHERE id_libro = NEW.id_libro;

    IF v_disp <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay ejemplares disponibles de este libro';
    END IF;
END$$

-- Después de prestar: descuenta un ejemplar disponible
CREATE TRIGGER trg_prestamo_ai
AFTER INSERT ON prestamo
FOR EACH ROW
BEGIN
    UPDATE libro
    SET ejemplares_disponibles = ejemplares_disponibles - 1
    WHERE id_libro = NEW.id_libro;
END$$

-- Al registrar la devolución: calcula la multa automáticamente
CREATE TRIGGER trg_prestamo_bu
BEFORE UPDATE ON prestamo
FOR EACH ROW
BEGIN
    IF OLD.fecha_devolucion IS NULL AND NEW.fecha_devolucion IS NOT NULL THEN
        SET NEW.multa = fn_calcular_multa(
                            fn_dias_retraso(NEW.fecha_limite, NEW.fecha_devolucion));
    END IF;
END$$

-- Después de devolver: suma un ejemplar disponible
CREATE TRIGGER trg_prestamo_au
AFTER UPDATE ON prestamo
FOR EACH ROW
BEGIN
    IF OLD.fecha_devolucion IS NULL AND NEW.fecha_devolucion IS NOT NULL THEN
        UPDATE libro
        SET ejemplares_disponibles = ejemplares_disponibles + 1
        WHERE id_libro = NEW.id_libro;
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- 4. VISTAS
-- =====================================================================

-- Catálogo de libros con autor, categoría y disponibilidad
CREATE VIEW vw_libros_detalle AS
SELECT l.id_libro,
       l.titulo,
       fn_nombre_completo(a.nombre, a.apellido) AS autor,
       c.nombre AS categoria,
       l.ejemplares_disponibles,
       fn_porcentaje_disponible(l.ejemplares_disponibles, l.ejemplares_totales) AS porcentaje_disponible
FROM libro l
JOIN autor a     ON l.id_autor = a.id_autor
JOIN categoria c ON l.id_categoria = c.id_categoria;

-- Préstamos que todavía no han sido devueltos
CREATE VIEW vw_prestamos_activos AS
SELECT p.id_prestamo,
       fn_nombre_completo(s.nombre, s.apellido) AS socio,
       l.titulo,
       p.fecha_prestamo,
       p.fecha_limite,
       fn_dias_retraso(p.fecha_limite, CURDATE()) AS dias_retraso,
       fn_calcular_multa(fn_dias_retraso(p.fecha_limite, CURDATE())) AS multa_estimada
FROM prestamo p
JOIN socio s ON p.id_socio = s.id_socio
JOIN libro l ON p.id_libro = l.id_libro
WHERE p.fecha_devolucion IS NULL;

-- Resumen por socio: cantidad de préstamos y total de multas
CREATE VIEW vw_resumen_socios AS
SELECT s.id_socio,
       fn_nombre_completo(s.nombre, s.apellido) AS socio,
       COUNT(p.id_prestamo) AS total_prestamos,
       IFNULL(SUM(p.multa), 0) AS total_multas
FROM socio s
LEFT JOIN prestamo p ON s.id_socio = p.id_socio
GROUP BY s.id_socio, s.nombre, s.apellido;

-- =====================================================================
-- 5. DATOS DE PRUEBA
-- =====================================================================

INSERT INTO categoria (nombre) VALUES
('Novela'), ('Cuento'), ('Tecnología'), ('Historia');

INSERT INTO autor (nombre, apellido, nacionalidad) VALUES
('Gabriel', 'García Márquez', 'Colombiana'),
('Julio', 'Cortázar', 'Argentina'),
('Juan', 'Rulfo', 'Mexicana'),
('Robert', 'Martin', 'Estadounidense');

INSERT INTO libro (titulo, isbn, anio_publicacion, ejemplares_totales, ejemplares_disponibles, id_autor, id_categoria) VALUES
('Cien años de soledad',            '978-0307474728', 1967, 3, 3, 1, 1),
('El amor en los tiempos del cólera','978-0307389732', 1985, 2, 2, 1, 1),
('Crónica de una muerte anunciada', '978-0307475763', 1981, 2, 2, 1, 1),
('Rayuela',                         '978-8437604572', 1963, 1, 1, 2, 1),
('Pedro Páramo',                    '978-8437604831', 1955, 2, 2, 3, 1),
('Clean Code',                      '978-0132350884', 2008, 2, 2, 4, 3);

INSERT INTO socio (cedula, nombre, apellido, correo, fecha_registro) VALUES
('1001234567', 'Laura',  'Pérez',   'laura.perez@correo.com',   '2026-01-15'),
('1007654321', 'Carlos', 'Gómez',   'carlos.gomez@correo.com',  '2026-02-10'),
('1009876543', 'Andrea', 'Martínez','andrea.martinez@correo.com','2026-03-05');

-- Los préstamos disparan automáticamente los triggers (descuentan stock)
INSERT INTO prestamo (id_libro, id_socio, fecha_prestamo, fecha_limite) VALUES
(1, 1, '2026-10-01', '2026-10-08'),
(6, 2, '2026-10-03', '2026-10-10'),
(4, 3, '2026-10-05', '2026-10-12');

-- Devolución con retraso (4 días tarde): el trigger calcula la multa
UPDATE prestamo
SET fecha_devolucion = '2026-10-12'
WHERE id_prestamo = 1;

-- =====================================================================
-- 6. CONSULTAS DE PRUEBA
-- =====================================================================

-- Catálogo con disponibilidad
SELECT * FROM vw_libros_detalle;

-- Préstamos pendientes
SELECT * FROM vw_prestamos_activos;

-- Resumen de socios (Laura debe tener multa de 2000)
SELECT * FROM vw_resumen_socios;

-- Probar funciones sueltas
SELECT fn_nombre_completo('laura', 'pérez')    AS nombre_completo,
       fn_iniciales('Laura', 'Pérez')          AS iniciales,
       fn_dias_retraso('2026-10-08','2026-10-12') AS dias_retraso,
       fn_calcular_multa(4)                    AS multa,
       fn_porcentaje_disponible(1, 3)          AS porcentaje;

-- Probar el trigger de validación (debe dar error: Rayuela solo tiene 1 ejemplar y ya está prestado)
-- INSERT INTO prestamo (id_libro, id_socio, fecha_prestamo, fecha_limite)
-- VALUES (4, 1, '2026-10-20', '2026-10-27');
