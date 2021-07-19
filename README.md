# Airbnb Data Mart : SQL Database for temporal renting of lodgings

## Overview
Inspired by the well-known website Airbnb, the Airbnb Data Mart is a SQL database featuring a database structure and stored procedures fit for the use case of temporal renting of lodgings.
The application supports the creation and managing of lodgings for hosts and the ability to make reservations for users.
Additionally the data mart is contained in a single file which can be installed on every server capable of interpreting MySQL or MariaDB.

## Features
* Creation of various types of lodgings
* Pre-defined furniture, rooms, rules and policies for structuring a lodging
* Support for search functionality according to characteristics or geographical location
* A proximity search feature, based on longitude and latitude
* Multiple currency support with automatic conversion
* Integrated reservation system for guests
* Procedures for managing financial data

## Installation
For using the data mart, you need a server environment which supports MySQL or MariaDB. For a local installation the XAMPP packages can be used.
1. Download XAMPP from [Apache Friends](https://www.apachefriends.org/) and the data_mart.sql file
2. Install XAMPP and start the XAMPP Control Panel
3. Start the Apache and MySQL module and open a webbrowser
4. Type localhost into the searchbar and press enter on the keyboard
5. In the dashboard click the PhpMyAdmin button in the upper right corner
6. In PhpMyAdmin click the Database button
7. Add a new database with the name "data_mart"
8. Click on the new data_mart database in the left sidebar
9. Then click on the Import button in the upper bar
10. Choose the data_mart.sql file
11. Uncheck the "Enable foreign key checks" option and click OK

## Usage
For using the Airbnb data mart refer to the manual file

## License
GPL-3.0 License
