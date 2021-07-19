DELIMITER //

CREATE PROCEDURE Guest_CloseOpenTransaction(
    IN username VARCHAR(128),
    IN amount DECIMAL(19,2),
    IN transaction_id INT,
    OUT message VARCHAR(128)
)

BEGIN
    DECLARE converted_amount DECIMAL(19,2);
    DECLARE exchange_guest VARCHAR(64);
    DECLARE exchange_lodging VARCHAR(64);

    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if there are open transactions corresponding to the given ID
        IF EXISTS(SELECT * FROM transactions WHERE transactions.ID = transaction_id AND transactions.Received = 0) THEN

            -- Query the exchange rates of the transaction
            SELECT transactions.ExchangeEuroLodging, transactions.ExchangeEuroGuest INTO exchange_lodging, exchange_guest FROM transactions
            WHERE transactions.ID = transaction_id; 

            -- Convert the given amount into the transactions currency
            SET converted_amount = ROUND(amount * exchange_guest / exchange_lodging, 2);

            -- Check if the given amount is the same as in the transaction (Amount approximately +/- 1 currency unit to account for rounding errors)
            IF (SELECT transactions.Amount FROM transactions WHERE transactions.ID = transaction_id) BETWEEN converted_amount - 1 AND converted_amount + 1 THEN
            
                -- Set the transaction to received
                UPDATE transactions SET transactions.Received = 1 WHERE transactions.ID = transaction_id;

                -- Return a success message
                SET message = "Set Transaction To Received";

            -- No transaction found
            ELSE
                SET message = "Action Failed - False Amount";
            END IF;

        -- Given amount does not correspond to a transaction
        ELSE
            SET message = "Action Failed - No Open Transaction Found";
        END IF;

    -- Invalid username
    ELSE
        SET message = "Action Failed - User Not Found";
    END IF;
END //

