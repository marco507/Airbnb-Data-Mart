DELIMITER //

CREATE PROCEDURE User_DeleteAccount(
    IN username VARCHAR(128),
    OUT message VARCHAR(128)
) 
BEGIN
	-- Declare Variables
    DECLARE is_host INT;
    DECLARE all_settled INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN
    
        -- Check if a user is a host or guest
        SELECT users.HostID 
        INTO is_host
        FROM users
        WHERE users.Username = username;

        -- If the user is a guest check for not received transactions
        IF is_host IS NULL THEN
            -- Query and count the unreceived transactions of the guest 
            SELECT COUNT(transactions.Received)
            INTO all_settled
            FROM transactions 
            INNER JOIN booking ON transactions.BookingID = booking.ID 
            INNER JOIN users ON booking.UsersID = users.ID 
            WHERE users.Username = username AND transactions.Received = 0;

            -- If all transactions are closed, delete the user
            IF all_settled = 0 THEN      
                DELETE FROM users WHERE users.Username = username;
                SET message = 'Account Deleted';

            -- If there are open transactions, give back an error message
            ELSE
                SET message = 'Deactivation Failed - Open Transaction';
            END IF;

        -- If the user is a host check for not settled transactions
        ELSE
            -- Query and count the unsettled transactions of the host 
            SELECT COUNT(transactions.Settled)
            INTO all_settled
            FROM transactions 
            INNER JOIN booking ON transactions.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            INNER JOIN users ON lodging.UsersID = users.ID 
            WHERE users.Username = username AND transactions.Settled = 0;

            -- If all transactions are closed, delete the first the location of all lodgings and then the user
            IF all_settled = 0 THEN

                START TRANSACTION;
                    
                    -- Query the ID's of the locations and save them
                    CREATE TEMPORARY TABLE delete_user_location_results 
                    AS (SELECT lodging.LocationID FROM lodging WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username));

                    -- Delete the user
                    DELETE FROM users WHERE users.Username = username;
                    
                    -- Delete all locations of the users lodgings
                    DELETE FROM location 
                    WHERE location.ID IN (SELECT LocationID FROM delete_user_location_results);

                    SET message = 'Account Deleted';
                COMMIT;

            -- If there are open transactions, give back an error message
            ELSE
                SET message = 'Deactivation Failed - Open Transaction';
            END IF;
        END IF;
	
    -- If the user does not exists return an error message
    ELSE
    	SET message = 'Deactivation Failed - User Does Not Exist';
    END IF;
	
END //