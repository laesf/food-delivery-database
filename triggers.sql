-- ELENCO TRIGGER
--
--  1.  carrello_before_insert      -> valida quantita, calcola prezzo automatico,
--                                     controlla allergeni
--  2.  carrello_after_insert       -> ricalcola totale ordine
--  3.  carrello_after_update       -> ricalcola totale ordine
--  4.  carrello_after_delete       -> ricalcola totale ordine
--  5.  recensione_before_insert    -> stato consegnato, voti [1-5]
--                                     (unicita garantita da UNIQUE KEY nel DDL)
--  6.  recensione_before_update    -> stato consegnato (se cambia ordine), voti [1-5]
--  7.  recensione_after_insert     -> aggiorna media_voti ristorante
--  8.  recensione_after_update     -> aggiorna media_voti ristorante
--  9.  recensione_after_delete     -> aggiorna media_voti ristorante
-- 10.  ordine_after_insert         -> incrementa contatore impegnato del rider
--                                     se l'ordine e attivo
-- 11.  ordine_after_update         -> aggiorna il contatore su cambio rider,
--                                     chiusura e riapertura dell'ordine
--
--
-- OPERATORE <=> (NULL-safe equal, MariaDB/MySQL):
--   a <=> b         TRUE se uguali o entrambi NULL
--   NOT (a <=> b)   TRUE se diversi, anche se uno e NULL

DELIMITER $$

-- DROP IF EXISTS (idempotenza)
DROP TRIGGER IF EXISTS `carrello_before_insert`$$
DROP TRIGGER IF EXISTS `carrello_after_insert`$$
DROP TRIGGER IF EXISTS `carrello_after_update`$$
DROP TRIGGER IF EXISTS `carrello_after_delete`$$
DROP TRIGGER IF EXISTS `recensione_before_insert`$$
DROP TRIGGER IF EXISTS `recensione_before_update`$$
DROP TRIGGER IF EXISTS `recensione_after_insert`$$
DROP TRIGGER IF EXISTS `recensione_after_update`$$
DROP TRIGGER IF EXISTS `recensione_after_delete`$$
DROP TRIGGER IF EXISTS `ordine_after_insert`$$
DROP TRIGGER IF EXISTS `ordine_after_update`$$


-- -------------------------------------------------------
-- TRIGGER 1: carrello_before_insert
-- BEFORE INSERT ON carrello
--
-- (a) Valida quantita: deve essere NOT NULL e > 0.
-- (b) Calcola prezzo automatico se NULL:
--     prezzo = imponibile * (1 + iva / 100)
--     Se imponibile o iva sono NULL, NEW.prezzo rimane NULL
--     (coerente con il DDL che ammette NULL su prezzo).
-- (c) Recupera il cliente collegato all'ordine.
-- (d) Controlla allergeni: blocca se il piatto contiene
--     un allergene registrato per il cliente dell'ordine.
--
-- Un unico CONTINUE HANDLER FOR NOT FOUND copre entrambi i
-- SELECT INTO: se il piatto non esiste, v_imponibile/v_iva
-- restano NULL; se l'ordine non esiste, v_cliente resta NULL.
-- -------------------------------------------------------

CREATE TRIGGER `carrello_before_insert`
BEFORE INSERT ON `carrello`
FOR EACH ROW
BEGIN
    DECLARE v_cliente        INT           DEFAULT NULL;
    DECLARE v_imponibile     DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_iva            INT           DEFAULT NULL;
    DECLARE v_allergene_nome VARCHAR(255)  DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

    -- (a) Validazione quantita
    IF NEW.quantita IS NULL OR NEW.quantita <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La quantita deve essere un numero intero positivo.';
    END IF;

    -- (b) Calcolo prezzo automatico se non fornito
    IF NEW.prezzo IS NULL THEN
        SELECT `imponibile`, `iva`
        INTO v_imponibile, v_iva
        FROM `piatto`
        WHERE `id` = NEW.piatto;

        IF v_imponibile IS NOT NULL AND v_iva IS NOT NULL THEN
            SET NEW.prezzo = v_imponibile * (1 + v_iva / 100);
        END IF;
    END IF;

    -- (c) Recupera il cliente collegato all'ordine
    SELECT `utente`
    INTO v_cliente
    FROM `ordine`
    WHERE `id` = NEW.ordine;

    -- (d) Controllo allergeni solo se esiste il cliente
    IF v_cliente IS NOT NULL THEN

        SELECT a.`allergene`
        INTO v_allergene_nome
        FROM `alergene_piatto` ap
        JOIN `allergeni` a ON ap.allergene = a.id
        WHERE ap.piatto = NEW.piatto
          AND ap.allergene IN (
              SELECT allergene
              FROM `alergene_utente`
              WHERE cliente = v_cliente
          )
        LIMIT 1;

        IF v_allergene_nome IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Attenzione: il piatto contiene un allergene registrato per questo cliente.';
        END IF;

    END IF;

END$$


-- -------------------------------------------------------
-- TRIGGER 2: carrello_after_insert
-- AFTER INSERT ON carrello
--
-- Ricalcola il campo totale dell'ordine corrispondente.
-- COALESCE(SUM(...), 0) gestisce il caso in cui tutte le
-- righe abbiano prezzo o quantita NULL.
-- -------------------------------------------------------

CREATE TRIGGER `carrello_after_insert`
AFTER INSERT ON `carrello`
FOR EACH ROW
BEGIN
    UPDATE `ordine`
    SET `totale` = (
        SELECT COALESCE(SUM(`prezzo` * `quantita`), 0)
        FROM `carrello`
        WHERE `ordine` = NEW.ordine
    )
    WHERE `id` = NEW.ordine;
END$$


-- -------------------------------------------------------
-- TRIGGER 3: carrello_after_update
-- AFTER UPDATE ON carrello
--
-- Ricalcola il totale dopo ogni modifica.
-- carrello.ordine e parte della PK -> NOT NULL -> <> e sicuro.
-- Se la colonna ordine cambia, ricalcola anche il vecchio ordine.
-- -------------------------------------------------------

CREATE TRIGGER `carrello_after_update`
AFTER UPDATE ON `carrello`
FOR EACH ROW
BEGIN
    UPDATE `ordine`
    SET `totale` = (
        SELECT COALESCE(SUM(`prezzo` * `quantita`), 0)
        FROM `carrello`
        WHERE `ordine` = NEW.ordine
    )
    WHERE `id` = NEW.ordine;

    IF OLD.ordine <> NEW.ordine THEN
        UPDATE `ordine`
        SET `totale` = (
            SELECT COALESCE(SUM(`prezzo` * `quantita`), 0)
            FROM `carrello`
            WHERE `ordine` = OLD.ordine
        )
        WHERE `id` = OLD.ordine;
    END IF;
END$$


-- -------------------------------------------------------
-- TRIGGER 4: carrello_after_delete
-- AFTER DELETE ON carrello
--
-- Ricalcola il totale dopo la rimozione di una riga.
-- Se il carrello diventa vuoto, SUM = NULL -> COALESCE -> 0.
-- -------------------------------------------------------

CREATE TRIGGER `carrello_after_delete`
AFTER DELETE ON `carrello`
FOR EACH ROW
BEGIN
    UPDATE `ordine`
    SET `totale` = (
        SELECT COALESCE(SUM(`prezzo` * `quantita`), 0)
        FROM `carrello`
        WHERE `ordine` = OLD.ordine
    )
    WHERE `id` = OLD.ordine;
END$$


-- -------------------------------------------------------
-- TRIGGER 5: recensione_before_insert
-- BEFORE INSERT ON recensione
--
-- (a) Stato ordine: blocca se l'ordine non e 'consegnato'.
--     Se NEW.ordine e NULL o l'ordine non esiste, v_stato
--     rimane NULL (via CONTINUE HANDLER) e la condizione blocca.
-- (b) Valida voto_ristorante in [1, 5] se fornito.
-- (c) Valida voto_rider in [1, 5] se fornito.
--
-- L'unicita recensione per ordine e garantita dal vincolo
-- UNIQUE KEY recensione_ordine_unique nel DDL (atomico,
-- senza race condition).
-- -------------------------------------------------------

CREATE TRIGGER `recensione_before_insert`
BEFORE INSERT ON `recensione`
FOR EACH ROW
BEGIN
    DECLARE v_stato VARCHAR(255) DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

    -- (a) Stato ordine
    SELECT `stato`
    INTO v_stato
    FROM `ordine`
    WHERE `id` = NEW.ordine;

    IF v_stato IS NULL OR v_stato <> 'consegnato' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Impossibile recensire: l''ordine non risulta consegnato.';
    END IF;

    -- (b) Valida voto_ristorante
    IF NEW.voto_ristorante IS NOT NULL
       AND (NEW.voto_ristorante < 1 OR NEW.voto_ristorante > 5) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Il voto del ristorante deve essere compreso tra 1 e 5.';
    END IF;

    -- (c) Valida voto_rider
    IF NEW.voto_rider IS NOT NULL
       AND (NEW.voto_rider < 1 OR NEW.voto_rider > 5) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Il voto del rider deve essere compreso tra 1 e 5.';
    END IF;
END$$


-- -------------------------------------------------------
-- TRIGGER 6: recensione_before_update
-- BEFORE UPDATE ON recensione
--
-- (a) Se recensione.ordine cambia (NULL-safe con <=>):
--     verifica che il NUOVO ordine sia in stato 'consegnato'.
--     Se il nuovo ordine non esiste o ha stato NULL, blocca.
-- (b) Valida voto_ristorante in [1, 5] se fornito.
-- (c) Valida voto_rider in [1, 5] se fornito.
-- -------------------------------------------------------

CREATE TRIGGER `recensione_before_update`
BEFORE UPDATE ON `recensione`
FOR EACH ROW
BEGIN
    DECLARE v_stato VARCHAR(255) DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

    -- (a) Se l'ordine collegato cambia, verifica stato del nuovo ordine
    IF NOT (OLD.ordine <=> NEW.ordine) THEN
        SELECT `stato`
        INTO v_stato
        FROM `ordine`
        WHERE `id` = NEW.ordine;

        IF v_stato IS NULL OR v_stato <> 'consegnato' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Impossibile collegare la recensione: il nuovo ordine non risulta consegnato.';
        END IF;
    END IF;

    -- (b) Valida voto_ristorante
    IF NEW.voto_ristorante IS NOT NULL
       AND (NEW.voto_ristorante < 1 OR NEW.voto_ristorante > 5) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Il voto del ristorante deve essere compreso tra 1 e 5.';
    END IF;

    -- (c) Valida voto_rider
    IF NEW.voto_rider IS NOT NULL
       AND (NEW.voto_rider < 1 OR NEW.voto_rider > 5) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Il voto del rider deve essere compreso tra 1 e 5.';
    END IF;
END$$


-- -------------------------------------------------------
-- TRIGGER 7: recensione_after_insert
-- AFTER INSERT ON recensione
--
-- Aggiorna media_voti del ristorante dopo una nuova recensione.
-- Percorso: recensione -> ordine -> carrello -> piatto -> ristorante
-- -------------------------------------------------------

CREATE TRIGGER `recensione_after_insert`
AFTER INSERT ON `recensione`
FOR EACH ROW
BEGIN
    DECLARE v_ristorante_id INT DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

    SELECT p.`ristorante`
    INTO v_ristorante_id
    FROM `carrello` c
    JOIN `piatto` p ON c.piatto = p.id
    WHERE c.ordine = NEW.ordine
      AND p.ristorante IS NOT NULL
    LIMIT 1;

    IF v_ristorante_id IS NOT NULL THEN
        UPDATE `ristorante`
        SET `media_voti` = (
            SELECT ROUND(AVG(voto), 2)
            FROM (
                SELECT DISTINCT r.`id`, r.`voto_ristorante` AS voto
                FROM `recensione` r
                JOIN `ordine` o   ON r.ordine = o.id
                JOIN `carrello` c ON c.ordine = o.id
                JOIN `piatto` p   ON c.piatto = p.id
                WHERE p.ristorante      = v_ristorante_id
                  AND r.voto_ristorante IS NOT NULL
            ) sub
        )
        WHERE `id` = v_ristorante_id;
    END IF;
END$$


-- -------------------------------------------------------
-- TRIGGER 8: recensione_after_update
-- AFTER UPDATE ON recensione
--
-- Aggiorna media_voti dopo una modifica.
-- Se l'ordine cambia, ricalcola anche il ristorante precedente.
-- -------------------------------------------------------

CREATE TRIGGER `recensione_after_update`
AFTER UPDATE ON `recensione`
FOR EACH ROW
BEGIN
    DECLARE v_ristorante_new INT DEFAULT NULL;
    DECLARE v_ristorante_old INT DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

    -- Ristorante del nuovo ordine
    SELECT p.`ristorante`
    INTO v_ristorante_new
    FROM `carrello` c
    JOIN `piatto` p ON c.piatto = p.id
    WHERE c.ordine = NEW.ordine
      AND p.ristorante IS NOT NULL
    LIMIT 1;

    IF v_ristorante_new IS NOT NULL THEN
        UPDATE `ristorante`
        SET `media_voti` = (
            SELECT ROUND(AVG(voto), 2)
            FROM (
                SELECT DISTINCT r.`id`, r.`voto_ristorante` AS voto
                FROM `recensione` r
                JOIN `ordine` o   ON r.ordine = o.id
                JOIN `carrello` c ON c.ordine = o.id
                JOIN `piatto` p   ON c.piatto = p.id
                WHERE p.ristorante      = v_ristorante_new
                  AND r.voto_ristorante IS NOT NULL
            ) sub
        )
        WHERE `id` = v_ristorante_new;
    END IF;

    -- Se l'ordine e cambiato, aggiorna anche il ristorante precedente
    IF NOT (OLD.ordine <=> NEW.ordine) THEN
        SET v_ristorante_old = NULL;

        SELECT p.`ristorante`
        INTO v_ristorante_old
        FROM `carrello` c
        JOIN `piatto` p ON c.piatto = p.id
        WHERE c.ordine = OLD.ordine
          AND p.ristorante IS NOT NULL
        LIMIT 1;

        IF v_ristorante_old IS NOT NULL
           AND NOT (v_ristorante_old <=> v_ristorante_new) THEN
            UPDATE `ristorante`
            SET `media_voti` = COALESCE(
                (
                    SELECT ROUND(AVG(voto), 2)
                    FROM (
                        SELECT DISTINCT r.`id`, r.`voto_ristorante` AS voto
                        FROM `recensione` r
                        JOIN `ordine` o   ON r.ordine = o.id
                        JOIN `carrello` c ON c.ordine = o.id
                        JOIN `piatto` p   ON c.piatto = p.id
                        WHERE p.ristorante      = v_ristorante_old
                          AND r.voto_ristorante IS NOT NULL
                    ) sub
                ),
                0
            )
            WHERE `id` = v_ristorante_old;
        END IF;
    END IF;
END$$


-- -------------------------------------------------------
-- TRIGGER 9: recensione_after_delete
-- AFTER DELETE ON recensione
--
-- Aggiorna media_voti dopo eliminazione.
-- Se non rimangono recensioni, COALESCE azzera a 0.
-- -------------------------------------------------------

CREATE TRIGGER `recensione_after_delete`
AFTER DELETE ON `recensione`
FOR EACH ROW
BEGIN
    DECLARE v_ristorante_id INT DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

    SELECT p.`ristorante`
    INTO v_ristorante_id
    FROM `carrello` c
    JOIN `piatto` p ON c.piatto = p.id
    WHERE c.ordine = OLD.ordine
      AND p.ristorante IS NOT NULL
    LIMIT 1;

    IF v_ristorante_id IS NOT NULL THEN
        UPDATE `ristorante`
        SET `media_voti` = COALESCE(
            (
                SELECT ROUND(AVG(voto), 2)
                FROM (
                    SELECT DISTINCT r.`id`, r.`voto_ristorante` AS voto
                    FROM `recensione` r
                    JOIN `ordine` o   ON r.ordine = o.id
                    JOIN `carrello` c ON c.ordine = o.id
                    JOIN `piatto` p   ON c.piatto = p.id
                    WHERE p.ristorante      = v_ristorante_id
                      AND r.voto_ristorante IS NOT NULL
                ) sub
            ),
            0
        )
        WHERE `id` = v_ristorante_id;
    END IF;
END$$


-- -------------------------------------------------------
-- TRIGGER 10: ordine_after_insert
-- AFTER INSERT ON ordine
--
-- Incrementa il contatore impegnato del rider (+1) se l'ordine
-- e attivo (stato diverso da 'consegnato' e 'annullato').
-- ordine.rider e VARCHAR(255) NOT NULL -> nessun rischio NULL.
-- -------------------------------------------------------

CREATE TRIGGER `ordine_after_insert`
AFTER INSERT ON `ordine`
FOR EACH ROW
BEGIN
    IF COALESCE(NEW.stato, '') NOT IN ('consegnato', 'annullato') THEN
        UPDATE `rider`
        SET `impegnato` = COALESCE(`impegnato`, 0) + 1
        WHERE `cf` = NEW.rider;
    END IF;
END$$


-- -------------------------------------------------------
-- TRIGGER 11: ordine_after_update
-- AFTER UPDATE ON ordine
--
-- Mantiene rider.impegnato uguale al numero di ordini attivi
-- (stato diverso da 'consegnato' e 'annullato') del rider:
--
-- (a) Il vecchio rider perde l'ordine se era attivo e cambia
--     rider oppure viene chiuso.
-- (b) Il nuovo rider acquisisce l'ordine se e attivo e cambia
--     rider oppure viene riaperto.
--
-- ordine.rider e NOT NULL -> <> e sicuro.
-- COALESCE(stato,'') evita UNKNOWN se lo stato e NULL.
-- -------------------------------------------------------

CREATE TRIGGER `ordine_after_update`
AFTER UPDATE ON `ordine`
FOR EACH ROW
BEGIN
    DECLARE v_era_attivo BOOLEAN DEFAULT COALESCE(OLD.stato, '') NOT IN ('consegnato', 'annullato');
    DECLARE v_e_attivo   BOOLEAN DEFAULT COALESCE(NEW.stato, '') NOT IN ('consegnato', 'annullato');

    -- (a) Decrementa il vecchio rider (non scende sotto 0)
    IF v_era_attivo AND (OLD.rider <> NEW.rider OR NOT v_e_attivo) THEN
        UPDATE `rider`
        SET `impegnato` = GREATEST(COALESCE(`impegnato`, 0) - 1, 0)
        WHERE `cf` = OLD.rider;
    END IF;

    -- (b) Incrementa il nuovo rider
    IF v_e_attivo AND (OLD.rider <> NEW.rider OR NOT v_era_attivo) THEN
        UPDATE `rider`
        SET `impegnato` = COALESCE(`impegnato`, 0) + 1
        WHERE `cf` = NEW.rider;
    END IF;
END$$


DELIMITER ;
