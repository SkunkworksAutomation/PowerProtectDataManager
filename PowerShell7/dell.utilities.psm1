function get-iamsecret {
    param (
        [Parameter( Mandatory=$false)]
        [string]$User
    )
    begin {
            <#
                THIS IS MY FAKE IDENITY ACCESS MANAGEMENT SERVER!
                
                MODIFIED CODE EXAMPLE FROM:    
                    https://ilovepowershell.com/2021/08/19/the-random-password-generator-for-powershell-core-6-and-7/
                MODIFIED REGEX EXAMPLE FROM:
                    https://riptutorial.com/regex/example/18996/a-password-containing-at-least-1-uppercase--1-lowercase--1-digit--1-special-character-and-have-a-length-of-at-least-of-10

                POWERPROTECT DATA MANAGER DEFAULT PASSWORD COMPLEXITY
                400: The provided password must match the following password policy: The minimum length of password required is 16 and the maximum length of password required is not more than 20. 
                The password can't contain more than three consecutive identical characters. The minimum number of character categories required is 4. One lowercase character required at least. 
                One uppercase character required at least. One digit required at least. One special character required at least.
            
            #>
    }
    process {
        do {                
                # CHARACTER LIST TO IN INCLUDE IN PASSWORD
                $charlist = [char]94..[char]126 + [char]65..[char]90 +  [char]47..[char]57
                # BETWEEN 16 AND 20 CHARACTERS IN LENGTH
                $pwLength = (1..5 | Get-Random) + 15  
                $pwdList = @()

                for ($i = 0; $i -lt $pwlength; $i++) {
                    $pwdList += $charList | Get-Random
                }
                
                $pass = -join $pwdList
            }
            <#
                DO THIS UNTIL WE HAVE ATLEAST:
                MIN 16 CHARS, 1 UPPER, 1 LOWER, 1 NUMBER, 1 SPECIAL CHARACTER
            #>
            until ($pass -match '^(?=.{16,}$)(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*\W).*$')

            $Auth = [ordered]@{
                id = $User
                secret = $pass
                length = $pass.length
            }

            return $Auth;
    }
}