DELIMITER //

CREATE PROCEDURE Host_DeleteLodging(
    IN username VARCHAR(128),
    IN lodging VARCHAR(128),
    OUT message VARCHAR(128)
)

BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    DECLARE location_id INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to remove the lodging (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN

                -- Check if there is at least one booking
                IF EXISTS(SELECT * FROM booking WHERE booking.LodgingID = lodging_id) THEN
                
                    -- Check if there are open transactions
                        IF EXISTS(
                            SELECT * FROM transactions 
                            INNER JOIN booking ON transactions.BookingID = booking.ID
                            WHERE booking.LodgingID = lodging_id AND (transactions.Received = 0 OR transactions.Settled = 0)) THEN

                                SET message = 'Deletion Failed - Not Settled Transactions';

                        -- All transactions settled
                        ELSE
                            START TRANSACTION;
                                -- Query the location ID
                                SELECT LocationID INTO location_id FROM lodging WHERE ID = lodging_id;
                                -- Delete the Lodging
                                DELETE FROM lodging WHERE ID = lodging_id;
                                -- Delete the Location of the Lodging
                                DELETE FROM location WHERE location.ID = location_id;

                                -- If the host deleted all his lodging he becomes a guest
                                IF NOT EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id) THEN
                                    UPDATE users SET users.HostID = NULL WHERE users.ID = user_id;
                                END IF;

                                -- Return a success mesagge
                                SET message = 'Lodging Deleted';
                            COMMIT;
                        END IF;
                
                -- No bookings = No open transactions and the lodging can be deleted
                ELSE
                    START TRANSACTION;
                        -- Query the location ID
                        SELECT LocationID INTO location_id FROM lodging WHERE ID = lodging_id;
                        -- Delete the Lodging
                        DELETE FROM lodging WHERE ID = lodging_id;
                        -- Delete the Location of the Lodging
                        DELETE FROM location WHERE location.ID = location_id;

                        -- If the host deleted all his lodging he becomes a guest
                        IF NOT EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id) THEN
                            UPDATE users SET users.HostID = NULL WHERE users.ID = user_id;
                        END IF;
                    COMMIT;
                    SET message = 'Lodging Deleted';
                END IF;
        
            -- User is not the owner
            ELSE
                SET message = 'Deletion Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Deletion Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Deletion Failed - User Not Found';
    END IF;

END //