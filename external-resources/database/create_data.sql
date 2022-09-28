CREATE TABLE dbo.Users
(
	UserID varchar(50) NOT NULL,
	FirstName varchar(200) NOT NULL,
	Surname varchar(200) NOT NULL,
	CONSTRAINT PK_Users_UserID PRIMARY KEY CLUSTERED (UserID)
);

INSERT INTO dbo.Users VALUES ('63adbb5f-e6a1-4435-ba11-021e4928c9af','Sam','Shepard');
INSERT INTO dbo.Users VALUES ('df03858b-0b02-454b-b847-d2dab7da967e','Marilyn','Monroe');