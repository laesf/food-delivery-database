SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

-- Struttura della tabella `alergene_piatto`
CREATE TABLE `alergene_piatto` (
  `piatto`    int(11) NOT NULL,
  `allergene` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `alergene_utente`
CREATE TABLE `alergene_utente` (
  `cliente`   int(11) NOT NULL,
  `allergene` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `allergeni`
CREATE TABLE `allergeni` (
  `id`        int(10)      NOT NULL,
  `allergene` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `carrello`
CREATE TABLE `carrello` (
  `ordine`   int(10)       NOT NULL,
  `piatto`   int(11)       NOT NULL,
  `quantita` int(11)       DEFAULT NULL,
  `prezzo`   DECIMAL(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `categorie`
CREATE TABLE `categorie` (
  `id`         int(10)      NOT NULL,
  `created_at` timestamp    NOT NULL DEFAULT current_timestamp(),
  `nome`       varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `cliente`
CREATE TABLE `cliente` (
  `id`         int(10)      NOT NULL,
  `iscrizione` timestamp    NOT NULL DEFAULT current_timestamp(),
  `nome`       varchar(255) DEFAULT NULL,
  `cognome`    varchar(255) DEFAULT NULL,
  `mail`       varchar(255) DEFAULT NULL,
  `telefono`   varchar(255) DEFAULT NULL,
  `via`        varchar(255) DEFAULT NULL,
  `citta`      varchar(255) DEFAULT NULL,
  `cap`        varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `ordine`
CREATE TABLE `ordine` (
  `id`        int(10)       NOT NULL,
  `data`      timestamp     NOT NULL DEFAULT current_timestamp(),
  `utente`    int(11)       NOT NULL,
  `rider`     varchar(255)  NOT NULL,
  `indirizzo` varchar(255)  DEFAULT NULL,
  `totale`    DECIMAL(10,2) DEFAULT NULL,
  `stato`     varchar(255)  DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `paga`
CREATE TABLE `paga` (
  `id`   int(10)       NOT NULL,
  `data` timestamp     NOT NULL DEFAULT current_timestamp(),
  `paga` DECIMAL(10,2) DEFAULT NULL,
  `cf`   varchar(255)  DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `piatto`
CREATE TABLE `piatto` (
  `id`          int(10)       NOT NULL,
  `nome`        varchar(255)  DEFAULT NULL,
  `ristorante`  int(11)       DEFAULT NULL,
  `descrizione` varchar(255)  DEFAULT NULL,
  `imponibile`  DECIMAL(10,2) DEFAULT NULL,
  `iva`         int(11)       DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `recensione`
CREATE TABLE `recensione` (
  `id`              int(10)   NOT NULL,
  `created_at`      timestamp NOT NULL DEFAULT current_timestamp(),
  `ordine`          int(11)   DEFAULT NULL,
  `voto_ristorante` int(11)   DEFAULT NULL,
  `voto_rider`      int(11)   DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `rider`
CREATE TABLE `rider` (
  `cf`        varchar(255) NOT NULL,
  `nome`      varchar(255) NOT NULL,
  `cognome`   varchar(255) DEFAULT NULL,
  `paga`      int(11)      DEFAULT NULL,
  `impegnato` int(11)      NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `ristorante`
CREATE TABLE `ristorante` (
  `id`         int(10)       NOT NULL,
  `iscrizione` timestamp     NOT NULL DEFAULT current_timestamp(),
  `nome`       varchar(255)  DEFAULT NULL,
  `tipologia`  int(11)       DEFAULT NULL,
  `via`        varchar(255)  DEFAULT NULL,
  `citta`      varchar(255)  DEFAULT NULL,
  `media_voti` DECIMAL(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Struttura della tabella `ristorante_categoria`
CREATE TABLE `ristorante_categoria` (
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `ristorante` int(11)   NOT NULL,
  `categoria`  int(11)   NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Indici
ALTER TABLE `alergene_piatto`
  ADD PRIMARY KEY (`piatto`, `allergene`),
  ADD KEY `alergene_piatto_relation_2` (`allergene`);

ALTER TABLE `alergene_utente`
  ADD PRIMARY KEY (`cliente`, `allergene`),
  ADD KEY `alergene_utente_relation_2` (`allergene`);

ALTER TABLE `allergeni`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `carrello`
  ADD PRIMARY KEY (`ordine`, `piatto`),
  ADD KEY `carrello_relation_2` (`piatto`);

ALTER TABLE `categorie`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `cliente`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `ordine`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ordine_relation_1` (`rider`),
  ADD KEY `ordine_relation_2` (`utente`);

ALTER TABLE `paga`
  ADD PRIMARY KEY (`id`),
  ADD KEY `paga_relation_1` (`cf`);

ALTER TABLE `piatto`
  ADD PRIMARY KEY (`id`),
  ADD KEY `piatto_relation_1` (`ristorante`);

ALTER TABLE `recensione`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `recensione_ordine_unique` (`ordine`);

ALTER TABLE `rider`
  ADD PRIMARY KEY (`cf`);

ALTER TABLE `ristorante`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `ristorante_categoria`
  ADD PRIMARY KEY (`ristorante`, `categoria`),
  ADD KEY `ristorante_categoria_relation_2` (`categoria`);

-- AUTO_INCREMENT
ALTER TABLE `allergeni`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

ALTER TABLE `categorie`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

ALTER TABLE `cliente`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

ALTER TABLE `ordine`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

ALTER TABLE `paga`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

ALTER TABLE `piatto`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

ALTER TABLE `recensione`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

ALTER TABLE `ristorante`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;

-- Foreign keys
ALTER TABLE `alergene_piatto`
  ADD CONSTRAINT `alergene_piatto_relation_1` FOREIGN KEY (`piatto`)    REFERENCES `piatto`    (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `alergene_piatto_relation_2` FOREIGN KEY (`allergene`) REFERENCES `allergeni` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `alergene_utente`
  ADD CONSTRAINT `alergene_utente_relation_1` FOREIGN KEY (`cliente`)   REFERENCES `cliente`   (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `alergene_utente_relation_2` FOREIGN KEY (`allergene`) REFERENCES `allergeni` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `carrello`
  ADD CONSTRAINT `carrello_relation_1` FOREIGN KEY (`ordine`) REFERENCES `ordine` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `carrello_relation_2` FOREIGN KEY (`piatto`) REFERENCES `piatto` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `ordine`
  ADD CONSTRAINT `ordine_relation_1` FOREIGN KEY (`rider`)  REFERENCES `rider`   (`cf`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `ordine_relation_2` FOREIGN KEY (`utente`) REFERENCES `cliente` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `paga`
  ADD CONSTRAINT `paga_relation_1` FOREIGN KEY (`cf`) REFERENCES `rider` (`cf`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `piatto`
  ADD CONSTRAINT `piatto_relation_1` FOREIGN KEY (`ristorante`) REFERENCES `ristorante` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `recensione`
  ADD CONSTRAINT `recensione_relation_1` FOREIGN KEY (`ordine`) REFERENCES `ordine` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `ristorante_categoria`
  ADD CONSTRAINT `ristorante_categoria_relation_1` FOREIGN KEY (`ristorante`) REFERENCES `ristorante` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `ristorante_categoria_relation_2` FOREIGN KEY (`categoria`)  REFERENCES `categorie`  (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
