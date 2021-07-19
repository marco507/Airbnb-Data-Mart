DELIMITER //

CREATE PROCEDURE Guest_ShowLodgingDetails(
    IN username VARCHAR(128),
    IN lodging VARCHAR(128),
    OUT message VARCHAR(128)
)

BEGIN
    DECLARE exchange_guest DECIMAL(20,9);
    DECLARE exchange_host DECIMAL(20,9);

    -- Check if the lodging exists
    IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN

            -- Check if the username exists
            IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

            -- Query the current exchange rates of the guest and host
            SELECT currency.ExchangeRate INTO exchange_guest FROM currency
            INNER JOIN users ON users.CurrencyID = currency.ID
            WHERE users.username = username;

            SELECT currency.ExchangeRate INTO exchange_host FROM currency
            INNER JOIN lodging ON lodging.CurrencyID = currency.ID
            WHERE lodging.Description = lodging;

            -- Query the category, capacity and converted price of the lodging
            SELECT lodging.category, lodging.capacity, lodging.Rating, 
            (ROUND(lodging.Price * exchange_host / exchange_guest, 2)) AS "Price", 
            (SELECT currency.Name FROM currency INNER JOIN users ON users.CurrencyID = currency.ID WHERE users.Username = username) AS "Currency"
            FROM lodging
            WHERE lodging.Description = lodging;

            -- Query all furniture of the lodging
            SELECT furnishing.Description AS "Furniture"
            FROM lodging
            INNER JOIN lodging_furnishing ON lodging_furnishing.LodgingID = lodging.ID
            INNER JOIN furnishing ON lodging_furnishing.FurnishingID = furnishing.ID
            WHERE lodging.Description = lodging;

            -- Query all rooms of the lodging
            SELECT room.Description AS "Room", lodging_room.Number
            FROM lodging
            INNER JOIN lodging_room ON lodging_room.LodgingID = lodging.ID
            INNER JOIN room ON lodging_room.RoomID = room.ID
            WHERE lodging.Description = lodging;

            -- Query all rules of the lodging
            SELECT rule.Description AS "Rule"
            FROM lodging
            INNER JOIN lodging_rule ON lodging_rule.LodgingID = lodging.ID
            INNER JOIN rule ON lodging_rule.RuleID = rule.ID
            WHERE lodging.Description = lodging;

            -- Query all policies of the lodging
            SELECT policy.Description AS "Policy"
            FROM lodging
            INNER JOIN lodging_policy ON lodging_policy.LodgingID = lodging.ID
            INNER JOIN policy ON lodging_policy.PolicyID = policy.ID
            WHERE lodging.Description = lodging;

            -- Query all reviews of the lodging
            SELECT review.Content AS "Review", review.Rating
            FROM review
            INNER JOIN booking ON review.BookingID = booking.ID
            INNER JOIN lodging ON booking.LodgingID = lodging.ID
            WHERE lodging.Description = lodging;

            -- Return an message
            SET message = "Results";

        -- Incorrect username
        ELSE
            SET message = "Search Failed - User Not Found";
        END IF;

    -- Lodging does not exist
    ELSE
        SET message = "Search Failed - Lodging Not Found";
    END IF;
END //