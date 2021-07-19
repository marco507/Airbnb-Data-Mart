-- Currency
CREATE TABLE currency(
    ID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(64) NOT NULL UNIQUE,
    ExchangeRate DECIMAL(20, 9) NOT NULL,
    PRIMARY KEY(ID)
);
-- PaymentOption
CREATE TABLE paymentoption(
    ID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(64) NOT NULL UNIQUE,
    PRIMARY KEY(ID)
);
-- Continent
CREATE TABLE continent(
    ID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(16) NOT NULL UNIQUE,
    PRIMARY KEY(ID)
);
-- Country
CREATE TABLE country(
    ID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(64) NOT NULL UNIQUE,
    PRIMARY KEY(ID)
);
-- State
CREATE TABLE state(
    ID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(128) NOT NULL UNIQUE,
    PRIMARY KEY(ID)
);
-- City
CREATE TABLE city(
    ID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(128) NOT NULL UNIQUE,
    PRIMARY KEY(ID)
);
-- Furnishing
CREATE TABLE furnishing(
    ID INT NOT NULL AUTO_INCREMENT,
    Description VARCHAR(64) NOT NULL,
    PRIMARY KEY(ID)
);
-- Room
CREATE TABLE room(
    ID INT NOT NULL AUTO_INCREMENT,
    Description VARCHAR(64) NOT NULL,
    PRIMARY KEY(ID)
);
-- Rule
CREATE TABLE rule(
    ID INT NOT NULL AUTO_INCREMENT,
    Description VARCHAR(64) NOT NULL,
    PRIMARY KEY(ID)
);
-- Policy
CREATE TABLE policy(
    ID INT NOT NULL AUTO_INCREMENT,
    Description TEXT NOT NULL,
    PRIMARY KEY(ID)
);
-- Transaction
CREATE TABLE transaction(
    ID INT NOT NULL AUTO_INCREMENT,
    Amount DECIMAL(19, 2) NOT NULL,
    Price DECIMAL(19, 2) NOT NULL,
    Currency VARCHAR(64) NOT NULL,
    Received BOOLEAN NOT NULL DEFAULT FALSE,
    Settled BOOLEAN NOT NULL DEFAULT FALSE,
    ExchangeEuroLodging DECIMAL(20, 9) NOT NULL,
    ExchangeEuroGuest DECIMAL(20, 9) NOT NULL,
    PaymentOptionID INT NOT NULL,
    BookingID INT NOT NULL,
    PRIMARY KEY(ID),
    FOREIGN KEY(PaymentOptionID) REFERENCES paymentoption(ID),
    FOREIGN KEY(BookingID) REFERENCES booking(ID) ON DELETE CASCADE
);
-- Users
CREATE TABLE users(
    ID INT NOT NULL AUTO_INCREMENT,
    Username VARCHAR(128) NOT NULL UNIQUE,
    FirstName VARCHAR(128) NOT NULL,
    LastName VARCHAR(128) NOT NULL,
    Email VARCHAR(128) NOT NULL,
    Phone VARCHAR(20) NOT NULL,
    About TEXT,
    CurrencyID INT NOT NULL,
    HostID INT,
    PRIMARY KEY(ID),
    FOREIGN KEY(CurrencyID) REFERENCES currency(ID),
    FOREIGN KEY(HostID) REFERENCES users(ID) ON DELETE CASCADE
);
-- Location
CREATE TABLE location(
    ID INT NOT NULL AUTO_INCREMENT,
    Longitude DECIMAL(17,14) NOT NULL,
    Latitude DECIMAL(17,14) NOT NULL,
    Street VARCHAR(128) NOT NULL,
    CityID INT NOT NULL,
    StateID INT NOT NULL,
    CountryID INT NOT NULL,
    ContinentID INT NOT NULL,
    PRIMARY KEY(ID),
    FOREIGN KEY(CityID) REFERENCES city(ID),
    FOREIGN KEY(StateID) REFERENCES state(ID),
    FOREIGN KEY(CountryID) REFERENCES country(ID),
    FOREIGN KEY(ContinentID) REFERENCES continent(ID)
);
-- Lodging
CREATE TABLE lodging(
    ID INT NOT NULL AUTO_INCREMENT,
    Description VARCHAR(128) NOT NULL UNIQUE,
    Category VARCHAR(64) NOT NULL,
    About TEXT NOT NULL,
    Capacity INT NOT NULL,
    Rating DECIMAL(2, 1),
    Price DECIMAL(7, 2) NOT NULL,
    CurrencyID INT NOT NULL,
    LocationID INT NOT NULL,
    UsersID INT NOT NULL,
    PRIMARY KEY(ID),
    FOREIGN KEY(CurrencyID) REFERENCES currency(ID),
    FOREIGN KEY(LocationID) REFERENCES location(ID),
    FOREIGN KEY(UsersID) REFERENCES users(ID) ON DELETE CASCADE
);
-- PublicTransport
CREATE TABLE publictransport(
    ID INT NOT NULL AUTO_INCREMENT,
    Description VARCHAR(64) NOT NULL,
    LocationID INT NOT NULL,
    PRIMARY KEY(ID),
    FOREIGN KEY(LocationID) REFERENCES location(ID)
);
-- Sight
CREATE TABLE sight(
    ID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(128) NOT NULL UNIQUE,
    LocationID INT NOT NULL,
    PRIMARY KEY(ID),
    FOREIGN KEY(LocationID) REFERENCES location(ID)
);
-- Booking
CREATE TABLE booking(
    ID INT NOT NULL AUTO_INCREMENT,
    Arrival DATE NOT NULL,
    Departure DATE NOT NULL,
    UsersID INT,
    LodgingID INT NOT NULL,
    PRIMARY KEY(ID),
    FOREIGN KEY(UsersID) REFERENCES users(ID) ON DELETE SET NULL,
    FOREIGN KEY(LodgingID) REFERENCES lodging(ID) ON DELETE CASCADE
);
-- Lodging_Furnishing
CREATE TABLE lodging_furnishing(
    LodgingID INT NOT NULL,
    FurnishingID INT NOT NULL,
    PRIMARY KEY(LodgingID, FurnishingID),
    FOREIGN KEY(LodgingID) REFERENCES lodging(ID) ON DELETE CASCADE,
    FOREIGN KEY(FurnishingID) REFERENCES furnishing(ID)
);
-- Lodging_Room
CREATE TABLE lodging_room(
    LodgingID INT NOT NULL,
    RoomID INT NOT NULL,
    Number TINYINT NOT NULL,
    PRIMARY KEY(LodgingID, RoomID),
    FOREIGN KEY(LodgingID) REFERENCES lodging(ID) ON DELETE CASCADE,
    FOREIGN KEY(RoomID) REFERENCES room(ID)
);
-- Lodging_Rule
CREATE TABLE lodging_rule(
    LodgingID INT NOT NULL,
    RuleID INT NOT NULL,
    PRIMARY KEY(LodgingID, RuleID),
    FOREIGN KEY(LodgingID) REFERENCES lodging(ID) ON DELETE CASCADE,
    FOREIGN KEY(RuleID) REFERENCES rule(ID)
);
-- Lodging_Policy
CREATE TABLE lodging_policy(
    LodgingID INT NOT NULL,
    PolicyID INT NOT NULL,
    PRIMARY KEY(LodgingID, PolicyID),
    FOREIGN KEY(LodgingID) REFERENCES lodging(ID) ON DELETE CASCADE,
    FOREIGN KEY(PolicyID) REFERENCES policy(ID)
);
-- Review
CREATE TABLE review(
    ID INT NOT NULL AUTO_INCREMENT,
    Content TEXT NOT NULL,
    Rating DECIMAL(2, 1) NOT NULL,
    BookingID INT NOT NULL,
    PRIMARY KEY(ID),
    FOREIGN KEY(BookingID) REFERENCES booking(ID) ON DELETE CASCADE
);