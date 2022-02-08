
----SEQUENCES----


CREATE SEQUENCE seq_usuario
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE; 

CREATE SEQUENCE seq_game
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;

CREATE SEQUENCE seq_desenvolvedor
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;

CREATE SEQUENCE seq_genero
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;

CREATE SEQUENCE seq_venda
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;


----TABLES----


CREATE TABLE usuario
(
	ID                      INT NOT NULL DEFAULT nextval('public.seq_usuario')          	
	,nome_usuario           VARCHAR(50) NOT NULL UNIQUE
	,carteira               DECIMAL(5,2) DEFAULT 0
	,data_cadastro          TIMESTAMP NOT NULL
	,data_nascimento        DATE NOT NULL     
	
	,PRIMARY KEY (ID)
);

CREATE TABLE game
(
	ID                    INT NOT NULL DEFAULT nextval('public.seq_game')
	,nome_game            VARCHAR(50) NOT NULL UNIQUE
	,valor                DECIMAL(5,2) NOT NULL
	,data_lancamento      DATE NOT NULL
	,faixa_etaria         SMALLINT NOT NULL      

	,PRIMARY KEY (ID)
);

CREATE TABLE game_usuario
(
	usuario_id      INT NOT NULL
	,game_id        INT	NOT	NULL
	,horas_jogadas	DECIMAL(5,1) DEFAULT 0
	,avaliacao	    DECIMAL(1,1)

	,CONSTRAINT check_avaliacao	CHECK(avaliacao	BETWEEN	0 AND 5)      
	,FOREIGN KEY (usuario_id) REFERENCES usuario(ID)         
	,FOREIGN KEY (game_id) REFERENCES game(ID)
);

CREATE TABLE login_usuario
(
	usuario_id	   INT NOT NULL UNIQUE
	,e_mail	       VARCHAR(50) NOT NULL
	,senha		   VARCHAR(50) NOT NULL                             

	,CONSTRAINT	check_senha_len	CHECK(LENGTH(senha) >= 6)
	,PRIMARY KEY (e_mail)
	,FOREIGN KEY (usuario_id) REFERENCES usuario(ID)                   
);

CREATE TABLE genero
(
	ID	       INT NOT NULL DEFAULT nextval('public.seq_genero')
	,genero	   VARCHAR(25) NOT NULL UNIQUE
	
	,PRIMARY KEY (ID)            
);

CREATE TABLE desenvolvedor
(
	ID		             INT NOT NULL DEFAULT nextval('public.seq_desenvolvedor')
	,desenvolvedor       VARCHAR(50) NOT NULL UNIQUE

	,PRIMARY KEY (ID)       
);

CREATE TABLE game_genero
(
	game_id	     INT NOT NULL
	,genero_id   INT NOT NULL

	,FOREIGN KEY (game_id) REFERENCES game(ID)           
	,FOREIGN KEY (genero_id) REFERENCES genero(ID)
);

CREATE TABLE game_desenvolvedor
(
	game_id	            INT NOT NULL
	,desenvolvedor_id   INT NOT NULL

	,FOREIGN KEY (game_id) REFERENCES game(ID)           
	,FOREIGN KEY (desenvolvedor_id) REFERENCES desenvolvedor(ID)
);

CREATE TABLE venda
(
	ID        		INT NOT NULL DEFAULT nextval('public.seq_venda')
	,data           TIMESTAMP NOT NULL DEFAULT NOW()
	
	,PRIMARY KEY (ID)
);

CREATE TABLE venda_item
(
	venda_id        INT NOT NULL
	,game_id        INT NOT NULL
	,usuario_id     INT NOT NULL
	,valor          DECIMAL(5,2) NOT NULL 
	
	,FOREIGN KEY (venda_id) REFERENCES venda(ID)
	,FOREIGN KEY (game_id) REFERENCES game(ID)
	,FOREIGN KEY (usuario_id) REFERENCES usuario(ID)   
);




----Functions----


--Procedure que será executada quando a trigger 'trg_update_carteira'
--for ativada. 
--A procedure irá inserir registros na tabela 'game_usuario' e 
--fará um update na carteira do usuário, após qualquer insert na tabela 'venda_item'.   
CREATE OR REPLACE FUNCTION prc_update_carteira_for_trg()
RETURNS	TRIGGER
AS
$$	
BEGIN

	UPDATE usuario
		SET	carteira = carteira - NEW.valor
		WHERE ID = NEW.usuario_id;
	
	INSERT INTO game_usuario (usuario_id, game_id, horas_jogadas)
		VALUES(NEW.usuario_id,
			   NEW.game_id,
			   0);  
	
	RETURN	NULL;

END;
$$ LANGUAGE	plpgsql;


--Procedures--


--Procedure criada para inserir registros nas tabelas de vendas.   
CREATE OR REPLACE PROCEDURE prc_insert_venda(var_id_venda		INT,
											var_id_usuario		INT,
											var_id_game		    INT,
											var_valor			DECIMAL(5,2))
AS
$$
BEGIN      

	INSERT INTO venda(data)
		VALUES (NOW());

	INSERT INTO venda_item
		VALUES (var_id_venda,
				var_id_game,
				var_id_usuario,
				var_valor);

END;
$$ LANGUAGE plpgsql; 


--Procedure criada para inserir registros nas tabelas de usuário.
CREATE OR REPLACE PROCEDURE prc_insert_usuario(var_id_usuario		INT,
											  var_nome_usuario		VARCHAR(50),
											  var_data_nascimento	DATE,         
											  var_e_mail			VARCHAR(50),
											  var_senha			    VARCHAR(50))
AS 
$$
BEGIN

	INSERT INTO usuario(nome_usuario,carteira,data_cadastro,data_nascimento)
		VALUES (var_nome_usuario,
				0,
				NOW(),
				var_data_nascimento);

	INSERT INTO login_usuario
		VALUES (var_id_usuario,
				var_e_mail,
				var_senha);
				
END;
$$ LANGUAGE plpgsql;


----TRIGGERS----


-- Trigger que após uma venda atualizará o campo 'carteira' da tabela 'usuario' descontando o valor da venda
-- e também inserindo registros do usuário em relação ao j na tabela 'game_usuario'.             
CREATE OR REPLACE TRIGGER trg_update_carteira 
AFTER INSERT
ON venda_item
FOR EACH ROW
EXECUTE PROCEDURE prc_update_carteira_for_trg();


