# aptos-nft-ticket
A simple module which would mint an NFT to the user whenever they purchase a ticket.

In this module a person can do the following things
- Host a venue specifying the name and the description ( this is when an empty collection would be created )
- Create tickets for the venue by specifying name, description, uri, maximum tickets available and also the price. ( this is when token data would be created ).
- Users can purchase tickets by specifying the ticket name and the quantity. If the ticket purchase is successful, a NFT would be minted.
