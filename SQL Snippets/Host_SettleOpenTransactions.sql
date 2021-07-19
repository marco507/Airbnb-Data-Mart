DELIMITER //

CREATE PROCEDURE Host_SettleOpenTransactions(
    IN username VARCHAR(128),
    OUT message VARCHAR(128)
)

BEGIN

    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if there are unsettled transactions and received transactions
        IF EXISTS(
            SELECT * FROM transactions 
            INNER JOIN booking ON transactions.BookingID = booking.ID 
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 1 AND transactions.Settled = 0) THEN

            -- Set the unsettled transactions to settled
            UPDATE transactions
            INNER JOIN booking ON transactions.BookingID = booking.ID 
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            SET transactions.Settled = 1
            WHERE lodging.UsersID = (SELECT users.ID FROM users WHERE users.Username = username) AND transactions.Received = 1 AND transactions.Settled = 0;

            -- Return a success message
            SET message = "Transactions Set to Settled And Payment Initiated";

        -- No unsettled transactions
        ELSE
            SET message = "Action Failed - No Unsettled Transactions";
        END IF;

    -- User does not exist
    ELSE
        SET message = "Action Failed - User does not exist";
    END IF;
END //