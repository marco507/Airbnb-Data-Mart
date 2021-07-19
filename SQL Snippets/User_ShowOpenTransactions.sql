DELIMITER //

CREATE PROCEDURE User_ShowOpenTransactions(
    IN username VARCHAR(128),
    OUT message VARCHAR(128)
)

BEGIN
    -- Declare Varibles
    DECLARE is_host INT;

    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if a user is a host or guest
        SELECT users.HostID 
        INTO is_host
        FROM users
        WHERE users.Username = username;

        IF is_host IS NULL THEN

            -- Query all unreceived transactions
            SELECT transactions.ID,
            "Unreceived" AS "Status", 
            (SELECT ROUND(transactions.Amount * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS Total,
            "5%" AS "Fee",
            (SELECT ROUND(transactions.Price * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS "Price per Night",
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS Currency,
            booking.Arrival, booking.Departure, lodging.Description FROM transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE booking.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 0;

        ELSE
            
            -- Query all unreceived transactions
            SELECT transactions.ID,
            "Unreceived" AS "Status", 
            (SELECT ROUND(transactions.Amount * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS Total,
            "5%" AS "Fee",
            (SELECT ROUND(transactions.Price * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS "Price per Night",
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS Currency,
            booking.Arrival, booking.Departure, lodging.Description FROM transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE booking.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 0;

            -- Query all unsettled transactions
            SELECT transactions.ID,
            "Unsettled" AS "Status",
            (SELECT ROUND(transactions.Amount * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest * (100 / 105) ,2)) AS Total,
            (SELECT ROUND(transactions.Price * transactions.ExchangeEuroLodging / transactions.ExchangeEuroGuest,2)) AS "Price per Night",
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS Currency,
            booking.Arrival, booking.Departure, lodging.Description AS Lodging FROM transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 1 AND transactions.Settled = 0;
        END IF;

        -- Return a status message
        SET message = "Result";
        
    -- User does not exist
    ELSE
        SET message = "Search Failed - User does not exist";
    END IF;

END //

     