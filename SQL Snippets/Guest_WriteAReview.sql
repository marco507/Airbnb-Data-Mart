DELIMITER //

CREATE PROCEDURE Guest_WriteAReview(
    IN username VARCHAR(128),
    IN lodging VARCHAR(128),
    IN departure DATE,
    IN review TEXT,
    IN rating DECIMAL(2,1),
    OUT message VARCHAR(128)
) 

BEGIN

    DECLARE user_id INT;
    DECLARE lodging_id INT;
    DECLARE rating_sum FLOAT;
    DECLARE rating_count FLOAT;
    DECLARE new_rating DECIMAL(2,1);

    -- Check if the username exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN

            -- Check if the review or rating is missing
            IF review = '' OR rating = 0 THEN
                -- Return an error message
                SET message = 'Review Failed - Missing Parameters';

            ELSE
                -- Query the lodging ID
                SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

                -- Query the users ID
                SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

                    -- Check if the user is authorized to issue a review ( A booking exists for a user at a certain departure date )
                    IF EXISTS(SELECT * FROM booking WHERE (booking.LodgingID = lodging_id AND booking.UsersID = user_id AND booking.Departure = departure) ) THEN
                    
                        -- Check if there is already a review
                        IF EXISTS(SELECT * FROM review WHERE review.BookingID = (SELECT booking.ID FROM booking WHERE booking.UsersID = user_id AND booking.LodgingID = lodging_id)) THEN
                            -- Return an error message
                            SET message = "Review Failed - Only One Review Allowed";

                        -- Create a new entry for the review
                        ELSE    
                            START TRANSACTION;
                                INSERT INTO review 
                                VALUES(
                                    DEFAULT,
                                    review,
                                    rating,
                                    (SELECT booking.ID FROM booking WHERE booking.LodgingID = lodging_id AND booking.UsersID = user_id AND booking.Departure = departure)
                                );

                                -- Calculate the new rating of the lodging
                                SELECT SUM(review.Rating), COUNT(review.Rating) 
                                INTO rating_sum, rating_count 
                                FROM review
                                INNER JOIN booking ON review.BookingID = booking.ID
                                INNER JOIN lodging ON booking.LodgingID = lodging.ID
                                WHERE lodging.ID = lodging_id;

                                UPDATE lodging SET lodging.Rating = rating_sum / rating_count WHERE lodging.ID = lodging_id;

                                SET message = "Review Inserted";
                            COMMIT;
                        END IF;
            
                    -- No corresponding booking found
                    ELSE
                        SET message = "Review Failed - No Booking Found";
                    END IF;
            END IF;

        -- Invalid Lodging Name
        ELSE
            SET message = 'Review Failed - No Lodging Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Review Failed - False Username';
    END IF;
END //

