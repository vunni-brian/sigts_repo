const bcrypt = require('bcryptjs');

// Why we hashed our passwords:
// - To never store plain text passwords!
// - bcrypt adds "salt" (random data) to each password in db
// - Same password produces different hashes (prevents rainbow table attacks)

async function demonstrateHashing() {
    const password = 'mySecret123';
    
    // Hash the password (12 rounds of salting)
    const hashedPassword = await bcrypt.hash(password, 12);
    console.log('Original:', password);
    console.log('Hashed:', hashedPassword);
        
    // Process of verifying password
    const isValid = await bcrypt.compare(password, hashedPassword);
    console.log('Password valid:', isValid); // true
    
    // Wrong password
    const isInvalid = await bcrypt.compare('wrongPassword', hashedPassword);
    console.log('Wrong password valid:', isInvalid); // false
}

demonstrateHashing();
