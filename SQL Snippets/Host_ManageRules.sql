DELIMITER //

CREATE PROCEDURE Host_ManageRules(
    IN username VARCHAR(128),
    IN lodging VARCHAR(128),
    IN rules VARCHAR(256),
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

            -- Check if the user is authorized to change the lodging rules (Owner of the lodging)
            IF EXISTS(SELECT * FROM lodging WHERE lodging.UsersID = user_id AND lodging.ID = lodging_id) THEN
        
                -- Rule should be added
                IF action = 'Add' THEN
                
                    -- INSERT the Rule
                    INSERT INTO lodging_rule SELECT lodging_id, rule.ID FROM rule WHERE FIND_IN_SET(rule.Description,rules);

                    -- Return a success message
                    SET message = 'Added Rule';
                
                -- Rule should be removed
                ELSEIF action = 'Remove' THEN

                    -- DELETE the Rule
                    DELETE FROM lodging_rule
                    WHERE lodging_rule.LodgingID = lodging_id
                    AND lodging_rule.RuleID IN (SELECT rule.ID FROM rule WHERE FIND_IN_SET(rule.Description,rules));  

                    -- Return a success message
                    SET message = 'Removed Rule';
                
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