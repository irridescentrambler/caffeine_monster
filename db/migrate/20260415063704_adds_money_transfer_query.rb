# frozen_string_literal: true

# Adds money transfer script for atomicity
class AddsMoneyTransferQuery < ActiveRecord::Migration[7.1]
  SQL = <<~SQL
      CREATE PROCEDURE IF NOT EXISTS transferAmount(
        IN from_account_id INT,
        IN to_account_id INT,
        IN amount DECIMAL(10,2)
      )
    BEGIN
        DECLARE current_amount DECIMAL(10,2);
        DECLARE account_count INT;

        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            RESIGNAL;
        END;

        -- Validate inputs
        IF amount <= 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Transfer amount must be positive';
        END IF;

        IF from_account_id = to_account_id THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot transfer to the same account';
        END IF;

        START TRANSACTION;

            -- Lock in consistent order (lower ID first) to prevent deadlocks
            SELECT COUNT(*) INTO account_count
            FROM accounts
            WHERE id IN (from_account_id, to_account_id)
            ORDER BY id
            FOR UPDATE;

            IF account_count < 2 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'One or both accounts do not exist';
            END IF;

            -- Balance already locked from above
            SELECT balance INTO current_amount
            FROM accounts
            WHERE id = from_account_id;

            IF current_amount < amount THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient Balance';
            END IF;

            UPDATE accounts SET balance = balance - amount, updated_at = NOW() WHERE id = from_account_id;
            UPDATE accounts SET balance = balance + amount, updated_at = NOW() WHERE id = to_account_id;

        COMMIT;
    END
  SQL

  def up
    ActiveRecord::Base.connection.exec_query(SQL)
  end

  def down
    ActiveRecord::Base.connection.exec_query('DROP PROCEDURE IF EXISTS transferAmount')
  end
end
