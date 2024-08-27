CREATE OR REPLACE FUNCTION update_last_updated_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_last_updated_trigger
BEFORE UPDATE ON your_table_name
FOR EACH ROW
EXECUTE FUNCTION update_last_updated_column();

