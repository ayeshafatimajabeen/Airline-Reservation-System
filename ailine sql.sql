-- Airline Reservation System SQL Script
-- Objective: Create a SQL system to manage flights and bookings.
-- Tool: MySQL Workbench (or any MySQL client)

-- 1. Database Creation
-- Drop database if it exists to ensure a clean start
DROP DATABASE IF EXISTS AirlineReservationSystem;
CREATE DATABASE AirlineReservationSystem;
USE AirlineReservationSystem;

-- 2. Table Design and Schema Normalization
-- Table: Flights
-- Stores information about individual flights
CREATE TABLE Flights (
    flight_id VARCHAR(10) PRIMARY KEY,
    flight_number VARCHAR(10) NOT NULL UNIQUE,
    origin VARCHAR(50) NOT NULL,
    destination VARCHAR(50) NOT NULL,
    departure_time DATETIME NOT NULL,
    arrival_time DATETIME NOT NULL,
    total_seats INT NOT NULL,
    available_seats INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    CHECK (departure_time < arrival_time),
    CHECK (total_seats > 0),
    CHECK (available_seats >= 0 AND available_seats <= total_seats)
);

-- Table: Customers
-- Stores customer information
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(20)
);

-- Table: Bookings
-- Stores booking details, linking customers to flights
CREATE TABLE Bookings (
    booking_id VARCHAR(15) PRIMARY KEY,
    customer_id INT NOT NULL,
    flight_id VARCHAR(10) NOT NULL,
    booking_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    number_of_passengers INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('CONFIRMED', 'CANCELLED', 'PENDING') DEFAULT 'PENDING',
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id),
    CHECK (number_of_passengers > 0)
);

-- Table: Seats
-- Stores individual seat details for each flight
CREATE TABLE Seats (
    seat_id INT PRIMARY KEY AUTO_INCREMENT,
    flight_id VARCHAR(10) NOT NULL,
    seat_number VARCHAR(5) NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    booking_id VARCHAR(15), -- Nullable, links to booking if occupied
    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id),
    FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id),
    UNIQUE (flight_id, seat_number) -- Ensures unique seat number per flight
);

-- 3. Insert Sample Data

-- Sample Customers
INSERT INTO Customers (first_name, last_name, email, phone_number) VALUES
('Alice', 'Smith', 'alice.smith@example.com', '123-456-7890'),
('Bob', 'Johnson', 'bob.johnson@example.com', '987-654-3210'),
('Charlie', 'Brown', 'charlie.brown@example.com', '555-123-4567');

-- Sample Flights
INSERT INTO Flights (flight_id, flight_number, origin, destination, departure_time, arrival_time, total_seats, available_seats, price) VALUES
('FL001', 'AA101', 'New York', 'Los Angeles', '2025-08-01 08:00:00', '2025-08-01 11:00:00', 150, 150, 250.00),
('FL002', 'BA202', 'London', 'Paris', '2025-08-05 10:30:00', '2025-08-05 11:30:00', 100, 100, 120.50),
('FL003', 'CA303', 'Tokyo', 'Seoul', '2025-08-10 14:00:00', '2025-08-10 16:00:00', 200, 200, 300.00),
('FL004', 'AA102', 'Los Angeles', 'New York', '2025-08-01 12:00:00', '2025-08-01 15:00:00', 150, 150, 240.00);

-- Populate Seats for FL001 (150 seats)
DELIMITER //
CREATE PROCEDURE InsertSeatsForFlight(IN flight_id_param VARCHAR(10), IN total_seats_param INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= total_seats_param DO
        INSERT INTO Seats (flight_id, seat_number, is_available) VALUES
        (flight_id_param, CONCAT('A', LPAD(i, 3, '0')), TRUE);
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL InsertSeatsForFlight('FL001', 150);
CALL InsertSeatsForFlight('FL002', 100);
CALL InsertSeatsForFlight('FL003', 200);
CALL InsertSeatsForFlight('FL004', 150);

DROP PROCEDURE InsertSeatsForFlight;

-- Sample Bookings (initially pending, will be confirmed by trigger)
INSERT INTO Bookings (booking_id, customer_id, flight_id, number_of_passengers, total_amount, status) VALUES
('BKG001', 1, 'FL001', 2, 500.00, 'PENDING'), -- Alice books 2 seats on FL001
('BKG002', 2, 'FL002', 1, 120.50, 'PENDING'); -- Bob books 1 seat on FL002

-- 4. Triggers for Booking Updates and Cancellations

-- Trigger: After a new booking is inserted (or status changes to CONFIRMED)
-- Decrement available_seats in Flights and mark seats as unavailable in Seats table
DELIMITER //
CREATE TRIGGER trg_after_booking_insert
AFTER INSERT ON Bookings
FOR EACH ROW
BEGIN
    IF NEW.status = 'CONFIRMED' THEN
        -- Decrement available seats in Flights
        UPDATE Flights
        SET available_seats = available_seats - NEW.number_of_passengers
        WHERE flight_id = NEW.flight_id;

        -- Mark seats as unavailable and link to booking
        UPDATE Seats
        SET is_available = FALSE, booking_id = NEW.booking_id
        WHERE flight_id = NEW.flight_id AND is_available = TRUE
        LIMIT NEW.number_of_passengers;
    END IF;
END //
DELIMITER ;

-- Trigger: After a booking is updated (e.g., status changes to CONFIRMED or CANCELLED)
DELIMITER //
CREATE TRIGGER trg_after_booking_update
AFTER UPDATE ON Bookings
FOR EACH ROW
BEGIN
    -- If booking status changes from PENDING to CONFIRMED
    IF OLD.status = 'PENDING' AND NEW.status = 'CONFIRMED' THEN
        -- Decrement available seats in Flights
        UPDATE Flights
        SET available_seats = available_seats - NEW.number_of_passengers
        WHERE flight_id = NEW.flight_id;

        -- Mark seats as unavailable and link to booking
        UPDATE Seats
        SET is_available = FALSE, booking_id = NEW.booking_id
        WHERE flight_id = NEW.flight_id AND is_available = TRUE
        LIMIT NEW.number_of_passengers;
    END IF;

    -- If booking status changes to CANCELLED
    IF OLD.status != 'CANCELLED' AND NEW.status = 'CANCELLED' THEN
        -- Increment available seats in Flights
        UPDATE Flights
        SET available_seats = available_seats + OLD.number_of_passengers
        WHERE flight_id = OLD.flight_id;

        -- Mark seats as available and unlink from booking
        UPDATE Seats
        SET is_available = TRUE, booking_id = NULL
        WHERE booking_id = OLD.booking_id;
    END IF;
END //
DELIMITER ;

-- Manually confirm the initial bookings to fire the trigger
UPDATE Bookings SET status = 'CONFIRMED' WHERE booking_id = 'BKG001';
UPDATE Bookings SET status = 'CONFIRMED' WHERE booking_id = 'BKG002';

-- 5. Queries

-- Query 1: Available Seats for a Specific Flight
-- Example: Available seats for FL001
SELECT
    f.flight_number,
    f.origin,
    f.destination,
    f.departure_time,
    f.available_seats AS current_available_seats,
    (SELECT COUNT(*) FROM Seats WHERE flight_id = 'FL001' AND is_available = TRUE) AS actual_available_seats_in_seats_table
FROM
    Flights f
WHERE
    f.flight_id = 'FL001';

-- Query 2: Flight Search (by origin, destination, and date)
-- Example: Flights from New York to Los Angeles on 2025-08-01
SELECT
    flight_id,
    flight_number,
    origin,
    destination,
    departure_time,
    arrival_time,
    available_seats,
    price
FROM
    Flights
WHERE
    origin = 'New York' AND destination = 'Los Angeles'
    AND DATE(departure_time) = '2025-08-01'
    AND available_seats > 0;

-- Query 3: All Bookings for a Specific Customer
-- Example: Bookings for Alice Smith (customer_id 1)
SELECT
    b.booking_id,
    f.flight_number,
    f.origin,
    f.destination,
    f.departure_time,
    b.number_of_passengers,
    b.total_amount,
    b.status,
    b.booking_date
FROM
    Bookings b
JOIN
    Flights f ON b.flight_id = f.flight_id
WHERE
    b.customer_id = 1;

-- Query 4: Detailed Booking Information with Customer and Flight Details
SELECT
    b.booking_id,
    c.first_name,
    c.last_name,
    c.email,
    f.flight_number,
    f.origin,
    f.destination,
    f.departure_time,
    f.arrival_time,
    b.number_of_passengers,
    b.total_amount,
    b.status,
    b.booking_date
FROM
    Bookings b
JOIN
    Customers c ON b.customer_id = c.customer_id
JOIN
    Flights f ON b.flight_id = f.flight_id;

-- 6. Generate Booking Summary Report
-- Report showing total bookings and revenue per flight
SELECT
    f.flight_number,
    f.origin,
    f.destination,
    COUNT(b.booking_id) AS total_bookings,
    SUM(b.total_amount) AS total_revenue,
    SUM(b.number_of_passengers) AS total_passengers_booked
FROM
    Flights f
LEFT JOIN
    Bookings b ON f.flight_id = b.flight_id AND b.status = 'CONFIRMED'
GROUP BY
    f.flight_id, f.flight_number, f.origin, f.destination
ORDER BY
    total_revenue DESC;

-- Report showing customer booking activity
SELECT
    c.first_name,
    c.last_name,
    c.email,
    COUNT(b.booking_id) AS total_bookings_made,
    SUM(b.total_amount) AS total_spent
FROM
    Customers c
LEFT JOIN
    Bookings b ON c.customer_id = b.customer_id AND b.status = 'CONFIRMED'
GROUP BY
    c.customer_id, c.first_name, c.last_name, c.email
ORDER BY
    total_spent DESC;

-- 7. Flight Availability Views

-- View: v_FlightAvailability
-- Shows current flight status with available seats
CREATE VIEW v_FlightAvailability AS
SELECT
    flight_id,
    flight_number,
    origin,
    destination,
    departure_time,
    arrival_time,
    total_seats,
    available_seats,
    price,
    CASE
        WHEN available_seats = 0 THEN 'SOLD OUT'
        WHEN available_seats < 10 THEN 'LIMITED AVAILABILITY'
        ELSE 'AVAILABLE'
    END AS availability_status
FROM
    Flights;

-- Query the view
SELECT * FROM v_FlightAvailability;

-- View: v_DetailedSeatAvailability
-- Shows individual seat availability for all flights
CREATE VIEW v_DetailedSeatAvailability AS
SELECT
    s.flight_id,
    f.flight_number,
    s.seat_number,
    s.is_available,
    s.booking_id
FROM
    Seats s
JOIN
    Flights f ON s.flight_id = f.flight_id;

-- Query the detailed seat availability view for a specific flight
SELECT * FROM v_DetailedSeatAvailability WHERE flight_id = 'FL001';

-- Example of a booking cancellation to test trigger
-- INSERT INTO Bookings (booking_id, customer_id, flight_id, number_of_passengers, total_amount, status) VALUES
-- ('BKG003', 3, 'FL001', 1, 250.00, 'CONFIRMED'); -- Charlie books 1 seat on FL001
-- UPDATE Bookings SET status = 'CANCELLED' WHERE booking_id = 'BKG003';
