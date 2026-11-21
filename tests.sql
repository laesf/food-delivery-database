-- Test dei trigger definiti in triggers.sql.
--
-- Da eseguire su un database di test vuoto, dopo aver importato
-- deliv_data.sql e triggers.sql:
--
--   mysql test_db < tests.sql
--
-- I dati di prova vengono inseriti in una transazione annullata
-- al termine, quindi il database resta vuoto. Lo script stampa
-- l'esito di ogni verifica e un riepilogo finale.

DROP TEMPORARY TABLE IF EXISTS esiti;
CREATE TEMPORARY TABLE esiti (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  descrizione VARCHAR(255),
  ottenuto    VARCHAR(255),
  atteso      VARCHAR(255),
  superato    BOOLEAN
);

DROP PROCEDURE IF EXISTS verifica;
DROP PROCEDURE IF EXISTS verifica_errore;
DROP PROCEDURE IF EXISTS verifica_contatori;

DELIMITER $$

CREATE PROCEDURE verifica(IN descrizione VARCHAR(255), IN ottenuto VARCHAR(255), IN atteso VARCHAR(255))
BEGIN
    INSERT INTO esiti (descrizione, ottenuto, atteso, superato)
    VALUES (descrizione, ottenuto, atteso, ottenuto <=> atteso);
END$$

-- Esegue l'istruzione e verifica che un trigger la blocchi con SIGNAL.
CREATE PROCEDURE verifica_errore(IN descrizione VARCHAR(255), IN istruzione TEXT)
BEGIN
    DECLARE bloccata BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET bloccata = TRUE;

    SET @istruzione = istruzione;
    PREPARE stmt FROM @istruzione;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    INSERT INTO esiti (descrizione, ottenuto, atteso, superato)
    VALUES (descrizione, IF(bloccata, 'bloccata', 'eseguita'), 'bloccata', bloccata);
END$$

-- Conta i rider il cui contatore impegnato differisce dal numero
-- effettivo di ordini attivi assegnati.
CREATE PROCEDURE verifica_contatori(IN descrizione VARCHAR(255))
BEGIN
    CALL verifica(descrizione, (
        SELECT COUNT(*)
        FROM rider r
        WHERE r.impegnato <> (
            SELECT COUNT(*)
            FROM ordine o
            WHERE o.rider = r.cf
              AND COALESCE(o.stato, '') NOT IN ('consegnato', 'annullato')
        )
    ), '0');
END$$

DELIMITER ;

START TRANSACTION;

-- Dati di prova
INSERT INTO allergeni (id, allergene) VALUES (1, 'glutine'), (2, 'lattosio');
INSERT INTO cliente (id, nome) VALUES (1, 'Cliente allergico'), (2, 'Cliente');
INSERT INTO alergene_utente (cliente, allergene) VALUES (1, 2);
INSERT INTO ristorante (id, nome) VALUES (1, 'Ristorante A'), (2, 'Ristorante B');
INSERT INTO piatto (id, nome, ristorante, imponibile, iva) VALUES
  (1, 'Pasta',    1, 10.00, 10),
  (2, 'Gelato',   1,  5.00, 22),
  (3, 'Insalata', 2,  8.00, 10);
INSERT INTO alergene_piatto (piatto, allergene) VALUES (1, 1), (2, 2);
INSERT INTO rider (cf, nome) VALUES ('R1', 'Rider 1'), ('R2', 'Rider 2'), ('R3', 'Rider 3');

-- ordine_after_insert
INSERT INTO ordine (id, utente, rider, stato) VALUES
  (1, 1, 'R1', 'in consegna'),
  (2, 2, 'R1', 'in consegna'),
  (3, 2, 'R2', 'in consegna'),
  (4, 2, 'R3', 'in consegna');
CALL verifica('ordine_after_insert: R1 con due ordini attivi',
  (SELECT impegnato FROM rider WHERE cf = 'R1'), '2');

-- carrello_before_insert
CALL verifica_errore('carrello_before_insert: quantita zero',
  'INSERT INTO carrello (ordine, piatto, quantita) VALUES (1, 1, 0)');
CALL verifica_errore('carrello_before_insert: quantita NULL',
  'INSERT INTO carrello (ordine, piatto, quantita) VALUES (1, 1, NULL)');
CALL verifica_errore('carrello_before_insert: allergene del cliente',
  'INSERT INTO carrello (ordine, piatto, quantita) VALUES (1, 2, 1)');

INSERT INTO carrello (ordine, piatto, quantita) VALUES (1, 1, 2);
CALL verifica('carrello_before_insert: prezzo calcolato con IVA',
  (SELECT prezzo FROM carrello WHERE ordine = 1 AND piatto = 1), '11.00');

INSERT INTO carrello (ordine, piatto, quantita, prezzo) VALUES (2, 2, 1, 4.00);
CALL verifica('carrello_before_insert: prezzo esplicito mantenuto',
  (SELECT prezzo FROM carrello WHERE ordine = 2 AND piatto = 2), '4.00');

-- carrello_after_insert
CALL verifica('carrello_after_insert: totale ordine 1',
  (SELECT totale FROM ordine WHERE id = 1), '22.00');

-- carrello_after_update
UPDATE carrello SET quantita = 3 WHERE ordine = 1 AND piatto = 1;
CALL verifica('carrello_after_update: totale dopo cambio quantita',
  (SELECT totale FROM ordine WHERE id = 1), '33.00');

INSERT INTO carrello (ordine, piatto, quantita) VALUES (3, 3, 1);
UPDATE carrello SET ordine = 2 WHERE ordine = 3 AND piatto = 3;
CALL verifica('carrello_after_update: totale del nuovo ordine',
  (SELECT totale FROM ordine WHERE id = 2), '12.80');
CALL verifica('carrello_after_update: totale del vecchio ordine',
  (SELECT totale FROM ordine WHERE id = 3), '0.00');

-- carrello_after_delete
DELETE FROM carrello WHERE ordine = 2 AND piatto = 3;
CALL verifica('carrello_after_delete: totale ricalcolato',
  (SELECT totale FROM ordine WHERE id = 2), '4.00');

-- recensione_before_insert
CALL verifica_errore('recensione_before_insert: ordine non consegnato',
  'INSERT INTO recensione (ordine, voto_ristorante) VALUES (1, 4)');

UPDATE ordine SET stato = 'consegnato' WHERE id = 1;
CALL verifica('ordine_after_update: consegna decrementa il rider',
  (SELECT impegnato FROM rider WHERE cf = 'R1'), '1');

CALL verifica_errore('recensione_before_insert: voto ristorante fuori intervallo',
  'INSERT INTO recensione (ordine, voto_ristorante) VALUES (1, 6)');
CALL verifica_errore('recensione_before_insert: voto rider fuori intervallo',
  'INSERT INTO recensione (ordine, voto_rider) VALUES (1, 0)');

-- recensione_after_insert
INSERT INTO recensione (id, ordine, voto_ristorante, voto_rider) VALUES (1, 1, 4, 5);
CALL verifica('recensione_after_insert: media ristorante',
  (SELECT media_voti FROM ristorante WHERE id = 1), '4.00');

-- recensione_before_update
CALL verifica_errore('recensione_before_update: voto fuori intervallo',
  'UPDATE recensione SET voto_ristorante = 9 WHERE id = 1');
CALL verifica_errore('recensione_before_update: nuovo ordine non consegnato',
  'UPDATE recensione SET ordine = 2 WHERE id = 1');

-- recensione_after_update
UPDATE recensione SET voto_ristorante = 2 WHERE id = 1;
CALL verifica('recensione_after_update: media dopo cambio voto',
  (SELECT media_voti FROM ristorante WHERE id = 1), '2.00');

INSERT INTO carrello (ordine, piatto, quantita) VALUES (4, 3, 1);
UPDATE ordine SET stato = 'consegnato' WHERE id = 4;
UPDATE recensione SET ordine = 4 WHERE id = 1;
CALL verifica('recensione_after_update: media del nuovo ristorante',
  (SELECT media_voti FROM ristorante WHERE id = 2), '2.00');
CALL verifica('recensione_after_update: media del vecchio ristorante',
  (SELECT media_voti FROM ristorante WHERE id = 1), '0.00');

-- recensione_after_delete
DELETE FROM recensione WHERE id = 1;
CALL verifica('recensione_after_delete: media senza recensioni',
  (SELECT media_voti FROM ristorante WHERE id = 2), '0.00');

-- ordine_after_update
UPDATE ordine SET rider = 'R2' WHERE id = 2;
CALL verifica('ordine_after_update: cambio rider, vecchio rider',
  (SELECT impegnato FROM rider WHERE cf = 'R1'), '0');
CALL verifica('ordine_after_update: cambio rider, nuovo rider',
  (SELECT impegnato FROM rider WHERE cf = 'R2'), '2');

UPDATE ordine SET stato = 'annullato' WHERE id = 2;
CALL verifica('ordine_after_update: annullamento decrementa il rider',
  (SELECT impegnato FROM rider WHERE cf = 'R2'), '1');

INSERT INTO ordine (id, utente, rider, stato) VALUES (5, 2, 'R1', 'in consegna');
UPDATE ordine SET rider = 'R1', stato = 'consegnato' WHERE id = 3;
CALL verifica('ordine_after_update: cambio rider e consegna, vecchio rider',
  (SELECT impegnato FROM rider WHERE cf = 'R2'), '0');
CALL verifica('ordine_after_update: cambio rider e consegna, nuovo rider',
  (SELECT impegnato FROM rider WHERE cf = 'R1'), '1');
CALL verifica_contatori('contatori rider coerenti dopo i casi base');

INSERT INTO ordine (id, utente, rider, stato) VALUES
  (6, 2, 'R3', 'consegnato'),
  (7, 2, 'R3', 'annullato');
CALL verifica('ordine_after_insert: ordini gia chiusi non contano',
  (SELECT impegnato FROM rider WHERE cf = 'R3'), '0');

INSERT INTO ordine (id, utente, rider, stato) VALUES (8, 2, 'R3', NULL);
CALL verifica('ordine_after_insert: ordine senza stato conta come attivo',
  (SELECT impegnato FROM rider WHERE cf = 'R3'), '1');

UPDATE ordine SET rider = 'R2' WHERE id = 1;
CALL verifica('ordine_after_update: riassegnazione di ordine chiuso, vecchio rider',
  (SELECT impegnato FROM rider WHERE cf = 'R1'), '1');
CALL verifica('ordine_after_update: riassegnazione di ordine chiuso, nuovo rider',
  (SELECT impegnato FROM rider WHERE cf = 'R2'), '0');

UPDATE ordine SET stato = 'in consegna' WHERE id = 2;
CALL verifica('ordine_after_update: riapertura con stesso rider',
  (SELECT impegnato FROM rider WHERE cf = 'R2'), '1');

UPDATE ordine SET rider = 'R1', stato = 'in consegna' WHERE id = 6;
CALL verifica('ordine_after_update: riapertura con cambio rider, nuovo rider',
  (SELECT impegnato FROM rider WHERE cf = 'R1'), '2');
CALL verifica('ordine_after_update: riapertura con cambio rider, vecchio rider',
  (SELECT impegnato FROM rider WHERE cf = 'R3'), '1');

UPDATE ordine SET stato = 'in preparazione' WHERE id = 6;
UPDATE ordine SET indirizzo = 'Via Roma 1' WHERE id = 6;
CALL verifica('ordine_after_update: aggiornamenti di ordine attivo senza effetto',
  (SELECT impegnato FROM rider WHERE cf = 'R1'), '2');

UPDATE ordine SET rider = 'R2' WHERE id = 7;
CALL verifica('ordine_after_update: riassegnazione di ordine annullato',
  (SELECT impegnato FROM rider WHERE cf = 'R2'), '1');

UPDATE ordine SET stato = 'annullato' WHERE id = 8;
CALL verifica('ordine_after_update: annullamento di ordine senza stato',
  (SELECT impegnato FROM rider WHERE cf = 'R3'), '0');

CALL verifica_contatori('contatori rider coerenti dopo i casi limite');

SELECT descrizione, ottenuto, atteso, IF(superato, 'OK', 'FALLITO') AS esito
FROM esiti
ORDER BY id;

SELECT COUNT(*) AS verifiche, SUM(superato) AS superate, COUNT(*) - SUM(superato) AS fallite
FROM esiti;

ROLLBACK;

DROP PROCEDURE verifica;
DROP PROCEDURE verifica_errore;
DROP PROCEDURE verifica_contatori;
DROP TEMPORARY TABLE esiti;
