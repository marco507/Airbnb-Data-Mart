DELIMITER //

CREATE PROCEDURE Host_ManageRooms(
    IN username VARCHAR(128),
    IN lodging VARCHAR(128),
    IN rooms VARCHAR(256),
    IN amount VARCHAR(256),
    IN action VARCHAR(6),
    OUT message VARCHAR(128)
)

BEGIN
    DECLARE lodging_id INT;
    DECLARE user_id INT;
    DECLARE list_length INT;
    DECLARE i INT;
    
    -- Check if the user exists
    IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN

        -- Query the user ID
        SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

        -- Check if the lodging exists
        IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN    
            
            -- Query the Lodging ID
            SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;

            -- Check if the user is authorized to change the lodging rooms (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN
        
                -- Rooms should be added
                IF action = 'Add' THEN
                
                    -- Count the number of items in the rooms list
                    SELECT 
                    CHARACTER_LENGTH(rooms)  - 
                    CHARACTER_LENGTH(REPLACE(rooms,',',''))
                    INTO list_length;

                    -- Insert the rooms one-by-one
                    SET i = 1;
                    insert_loop: WHILE i <= list_length + 1 DO

                        INSERT INTO lodging_room VALUES(
                            lodging_id,
                            (SELECT room.ID FROM room WHERE room.Description = SUBSTRING_INDEX(SUBSTRING_INDEX(rooms,',',i),',',-1)),
                            (SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(amount,',',FIND_IN_SET(SUBSTRING_INDEX(SUBSTRING_INDEX(rooms,',',i),',',-1), rooms)), ',', -1))
                        );

                        SET i = i+1;
                    END WHILE insert_loop;

                    -- Return a success message
                    SET message = 'Added Rooms';
                
                -- Rooms should be removed
                ELSEIF action = 'Remove' THEN

                    -- DELETE the Rooms
                    DELETE FROM lodging_room
                    WHERE lodging_room.LodgingID = lodging_id
                    AND lodging_room.RoomID IN (SELECT room.ID FROM room WHERE FIND_IN_SET(room.Description,rooms));  

                    -- Return a success message
                    SET message = 'Removed Rooms';
                
                -- Invalid Command
                ELSE
                    SET message = 'Action Failed - Invalid Command - Please Enter Add Or Remove For Action';
                END IF;

            -- User is not the owner
            ELSE
                SET message = 'Action Failed - Access Denied';
            END IF;
        
        -- Invalid Lodging
        ELSE
            SET message = 'Action Failed - Lodging Not Found';
        END IF;

    -- Invalid Username
    ELSE
        SET message = 'Action Failed - User Not Found';
    END IF;

END //