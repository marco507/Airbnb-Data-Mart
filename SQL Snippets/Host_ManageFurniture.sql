DELIMITER //

CREATE PROCEDURE Host_ManageFurniture(
    IN username VARCHAR(128),
    IN lodging VARCHAR(128),
    IN furniture VARCHAR(256),
    IN action VARCHAR(6),
    OUT message VARCHAR(128)
)

BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to change the lodging furniture (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN
        
                -- Furniture should be added
                IF action = 'Add' THEN
                
                    -- INSERT the Furniture
                    INSERT INTO lodging_furnishing SELECT lodging_id, furnishing.ID FROM furnishing WHERE FIND_IN_SET(furnishing.Description,furniture);

                    -- Return a success message
                    SET message = 'Added Furniture';
                
                -- Furniture should be removed
                ELSEIF action = 'Remove' THEN

                    -- DELETE the Furniture
                    DELETE FROM lodging_furnishing
                    WHERE lodging_furnishing.LodgingID = lodging_id
                    AND lodging_furnishing.FurnishingID IN (SELECT furnishing.ID FROM furnishing WHERE FIND_IN_SET(furnishing.Description,furniture));  

                    -- Return a success message
                    SET message = 'Removed Furniture';
                
                -- Invalid Command
                ELSE
                    SET message = 'Furnishing Failed - Invalid Command - Please Enter Add Or Remove For Action';
                END IF;

            -- User is not the owner
            ELSE
                SET message = 'Furnishing Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Furnishing Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Furnishing Failed - User Not Found';
    END IF;

END //
