DELIMITER //

CREATE PROCEDURE Guest_BookAStay(
    IN username VARCHAR(128),
    IN lodging VARCHAR(128),
    IN arrival DATE,
    IN departure DATE,
    IN payment_option VARCHAR(64),
    OUT message VARCHAR(128)
) 
BEGIN
    -- Declare Variables
    DECLARE number_of_bookings INT;
    DECLARE user_id INT;
    DECLARE lodging_id INT;
    DECLARE last_booking INT;
    DECLARE amount DECIMAL(19,2);
    DECLARE stay_duration DECIMAL(6,2);
    
    -- Check if the lodging exists
    IF EXISTS(SELECT * FROM lodging WHERE lodging.Description = lodging) THEN

        -- Query the lodging ID
        SELECT lodging.ID INTO lodging_id FROM lodging WHERE lodging.Description = lodging;
    
    	-- Check if the user exists
        IF EXISTS(SELECT * FROM users WHERE users.Username = username) THEN
        
        	-- Check if the paymentoption exists
            IF EXISTS(SELECT * FROM paymentoption WHERE paymentoption.Name = payment_option) THEN
        
                -- Query the users ID
                SELECT users.ID INTO user_id FROM users WHERE users.Username = username;

                -- Check if the arrival date is in the future and the departure date is after the arrival date
                IF arrival < departure AND arrival > CURRENT_DATE THEN 

                    -- Check if there are any date conflicts for the booking
                    IF EXISTS(SELECT * FROM booking WHERE ( arrival BETWEEN booking.Arrival AND booking.Departure ) AND booking.LodgingID = lodging_id ) THEN
                        -- Return an error message
                        SET message = 'Booking Failed - The lodging is already reserved for that date';

                    -- Make a reservation         
                    ELSE
                        START TRANSACTION;
                            -- Insert the reservation into the booking table
                            INSERT INTO booking VALUES(DEFAULT, arrival, departure, user_id, lodging_id);
                      		-- Save the ID of the last reservation
                      		SELECT LAST_INSERT_ID() INTO last_booking;

			                -- Calculate the duration of the stay
                            SELECT DATEDIFF(departure, arrival) INTO stay_duration;
                            
                            -- Calculate the price of the stay = LodgingPricePerNight * DurationOfStay * 5%Commission
                             SELECT lodging.Price INTO amount FROM lodging WHERE lodging.ID = lodging_id;
                             SET amount = amount * stay_duration * 1.05;
                             SET amount = CONVERT(amount,DECIMAL(19,2));
       
                            -- Create the corresponding transaction
                            INSERT INTO transactions VALUES(
                                DEFAULT,
                                amount,
                                (SELECT lodging.Price FROM lodging WHERE lodging.ID = lodging_id), 
                                (SELECT lodging.CurrencyID FROM lodging WHERE lodging.ID = lodging_id), 
                                DEFAULT, 
                                DEFAULT, 
                                (SELECT currency.ExchangeRate FROM currency WHERE currency.ID = (SELECT lodging.CurrencyID FROM lodging WHERE lodging.ID = lodging_id )),
                                (SELECT currency.ExchangeRate FROM currency WHERE currency.ID = (SELECT users.CurrencyID FROM users WHERE users.Username = username)),
                                (SELECT paymentoption.ID FROM paymentoption WHERE paymentoption.Name = payment_option),
                                last_booking
                                );
                            SET message = 'Reservation made';
                      	COMMIT;
                    END IF;

                -- Date Check Failed
                ELSE
                    SET message = 'Booking Failed - False Date';
                END IF;
                                
            -- Invalid Paymentoption
            ELSE
                SET message = 'Booking Failed - False Payment Option';
            END IF;
                                        
        -- Invalid Username
        ELSE
            SET message = 'Booking Failed - False Username';
        END IF;
	
    -- Invalid Lodging Name
    ELSE
    	SET message = 'Booking Failed - No Lodging Found';
    END IF;
END //