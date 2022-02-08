
----SEQUENCES----


CREATE SEQUENCE seq_usuario
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE; 
GO

CREATE SEQUENCE seq_game
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;
GO

CREATE SEQUENCE seq_desenvolvedor
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;
GO

CREATE SEQUENCE seq_genero
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;
GO

CREATE SEQUENCE seq_venda
	START WITH 1
	MINVALUE 1
	MAXVALUE 10000
	CYCLE;
GO


----TABLES----

CREATE TABLE usuario
(
	ID                      INT NOT NULL DEFAULT NEXT VALUE FOR seq_usuario	
	,nome_usuario           VARCHAR(50) NOT NULL UNIQUE
	,carteira               DECIMAL(5,2) DEFAULT 0
	,data_cadastro          DATETIME NOT NULL
	,data_nascimento        DATE NOT NULL     
	
	,PRIMARY KEY (ID)
);
GO

CREATE TABLE game
(
	ID                    INT NOT NULL DEFAULT NEXT VALUE FOR seq_game	
	,nome_game            VARCHAR(50) NOT NULL UNIQUE
	,valor                DECIMAL(5,2) NOT NULL
	,data_lancamento      DATETIME NOT NULL
	,faixa_etaria         SMALLINT NOT NULL      

	,PRIMARY KEY (ID)
);
GO

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
GO

CREATE TABLE login_usuario
(
	usuario_id	   INT NOT NULL UNIQUE
	,e_mail	       VARCHAR(50) NOT NULL
	,senha		   VARCHAR(50) NOT NULL                             

	,CONSTRAINT	check_senha_len	CHECK(LEN(senha) >= 6)
	,PRIMARY KEY (e_mail)
	,FOREIGN KEY (usuario_id) REFERENCES usuario(ID)                   
);
GO

CREATE TABLE genero
(
	ID	       INT NOT NULL DEFAULT NEXT VALUE FOR seq_genero
	,genero	   VARCHAR(25) NOT NULL UNIQUE
	
	,PRIMARY KEY (ID)            
);
GO

CREATE TABLE desenvolvedor
(
	ID		             INT NOT NULL DEFAULT NEXT VALUE FOR seq_desenvolvedor
	,desenvolvedor       VARCHAR(50) NOT NULL UNIQUE

	,PRIMARY KEY (ID)       
);
GO

CREATE TABLE game_genero
(
	game_id	     INT NOT NULL
	,genero_id   INT NOT NULL

	,FOREIGN KEY (game_id) REFERENCES game(ID)           
	,FOREIGN KEY (genero_id) REFERENCES genero(ID)
);
GO

CREATE TABLE game_desenvolvedor
(
	game_id	            INT NOT NULL
	,desenvolvedor_id   INT NOT NULL

	,FOREIGN KEY (game_id) REFERENCES game(ID)           
	,FOREIGN KEY (desenvolvedor_id) REFERENCES desenvolvedor(ID)
);
GO

CREATE TABLE venda
(
	ID        		INT NOT NULL DEFAULT NEXT VALUE FOR seq_venda
	,usuario_id     INT NOT NULL
	,data           DATETIME NOT NULL DEFAULT GETDATE()
	
	,PRIMARY KEY (ID)
	,FOREIGN KEY (usuario_id) REFERENCES usuario(ID) 
);
GO

CREATE TABLE venda_item
(
	venda_id        INT NOT NULL
	,game_id        INT NOT NULL
	,valor          DECIMAL(5,2) NOT NULL 
	
	,FOREIGN KEY (venda_id) REFERENCES venda(ID)
	,FOREIGN KEY (game_id) REFERENCES game(ID)  
);
GO


----TRIGGERS----


-- Trigger que após uma venda atualizará o campo 'carteira' da tabela 'usuario' descontando o valor da venda
-- e também inserindo registros do usuário em relação ao jogo na tabela 'game_usuario'.             
CREATE OR ALTER TRIGGER trg_update_carteira_apos_venda
ON venda_item
FOR INSERT
AS
BEGIN
	--Declarando as variáveis.     
	DECLARE
		@valor	             DECIMAL(5,2)
		,@id_venda	         INT
		,@id_usuario         INT
		,@id_game			 INT;    
		                  	

	SELECT @id_venda = venda_id, @valor = valor ,@id_game = game_id FROM inserted;----}
	                                                                              ----}Preenchendo as variáveis.       
	SELECT @id_usuario = usuario_id FROM venda WHERE ID = @id_venda;              ----}  
	
	UPDATE usuario
		SET	carteira = carteira - @valor
		WHERE ID = @id_usuario;
	
	INSERT INTO game_usuario (usuario_id, game_id, horas_jogadas)
		VALUES(@id_usuario,
			   @id_game,
			   0);

END;
GO


----Procedures----


--Procedure criada para inserir registros nas tabelas de vendas.   
CREATE OR ALTER PROCEDURE prc_insert_venda
	@id_usuario		INT,
	@id_game		INT,
	@valor			DECIMAL(5,2)

AS
BEGIN
	
	DECLARE
		@sequencia	      INT,
		@idade_usuario    INT,
		@carteira_usuario DECIMAL(5,2);       

	IF NOT @id_usuario IN (SELECT ID FROM usuario)--Checando se o usuário já é cadastrado.    
		RETURN (SELECT 'Usuário não cadastrado.');

	IF NOT @id_game IN (SELECT ID FROM game)--Checando se o game existe em nosso software.  
		RETURN (SELECT 'Game não cadastrado.');
		
	SELECT @carteira_usuario = carteira FROM usuario WHERE ID =	@id_usuario;--Preenchendo a variável 'carteira'.
	
	IF @carteira_usuario < @valor
		RETURN (SELECT 'Valor em carteira insuficiente para a compra.');--Checando se o usuário tem o suficiente       
		                                                                --na carteira para fazer a compra.  

	--Inserindo idade do usuário na variável '@idade_usuario'.
	--Mas antes calculando a idade do usuário através da coluna 'data_nascimento'.                    
	SELECT @idade_usuario = ((DATEDIFF(MONTH, data_nascimento, data_atual))/12 -
			CASE WHEN (MONTH(data_nascimento) = MONTH(data_atual))
					  AND DAY(data_nascimento) > DAY(data_atual) THEN 1 ELSE 0
			END)
	FROM (SELECT data_nascimento,
				 GETDATE() as data_atual  
		  FROM usuario
		  WHERE ID = @id_usuario) subquery;
	--------------------------------------------------------------------------------

	IF @idade_usuario >= (SELECT faixa_etaria FROM game WHERE ID = @id_game)--Checando se o usuário tem idade           
		BEGIN                                                               --suficiente para jogar o game.  
			SET	@sequencia = NEXT VALUE FOR seq_venda;

			INSERT INTO venda
				VALUES (@sequencia,
						@id_usuario,
						GETDATE());

			INSERT INTO venda_item
				VALUES (@sequencia,
						@id_game,
						@valor);
		END;

	ELSE RETURN (SELECT 'Game inapropriado para o usuário, impossível realizar a venda.')              

END;
GO


--Procedure criada para inserir registros nas tabelas de usuário.
CREATE OR ALTER PROCEDURE prc_insert_usuario
	@nome_usuario		VARCHAR(50),
	@data_nascimento	DATE,
	@e_mail				VARCHAR(50),
	@senha				VARCHAR(50)

AS
BEGIN
	
	DECLARE
		@sequencia	INT;

	IF @nome_usuario IN (SELECT nome_usuario FROM usuario)--Checando se o nome de usuário escolhido                      
		RETURN (SELECT 'Nome de usuário não disponível.');--está disponível para uso.    

	IF LEN(@senha) < 6  
		RETURN (SELECT 'A senha deverá conter pelo menos 6 caracteres.');--Checando se a senha do usuário     
                                                                         --tem no mínimo 6 dígitos.                
	IF @e_mail IN (SELECT e_mail FROM login_usuario)
		RETURN (SELECT 'O e_mail inserido já é cadastrado.');--Checando se o endereço de e-mail do usuário  
		                                                     --já não está cadastrado.         
	SET	@sequencia = NEXT VALUE FOR seq_usuario;

	INSERT INTO usuario
		VALUES (@sequencia,
				@nome_usuario,
				0,
				GETDATE(),
				@data_nascimento);

	INSERT INTO login_usuario
		VALUES (@sequencia,
				@e_mail,
				@senha);

END;
GO


