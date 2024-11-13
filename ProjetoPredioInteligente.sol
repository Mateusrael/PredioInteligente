// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract BuildingManagement {
    
    struct Apartment {
        uint apartmentNumber;
        address owner;
        bool isForRent;
        bool isForSale;
        uint256 rentPrice;  
        uint256 salePrice;  
        address currentTenant;
    }
    
    struct RentalAgreement {
        address tenant;
        uint256 rentAmount; 
        uint startDate;
    }
    
    // Mapeamento do número do apartamento para a estrutura Apartment
    mapping(uint => Apartment) public apartments;
    
    // Mapeamento do número do apartamento para o acordo de aluguel
    mapping(uint => RentalAgreement) public rentalAgreements;
    
    // Lista para verificar números únicos de apartamentos
    mapping(uint => bool) private existingApartmentNumbers;
    
    // Eventos
    event ApartmentRegistered(uint apartmentNumber, address owner);
    event ApartmentListedForRent(uint apartmentNumber, uint256 rentPrice);
    event ApartmentRented(uint apartmentNumber, address tenant, uint256 rentAmount);
    event RentalTerminated(uint apartmentNumber);
    event RentListingRemoved(uint apartmentNumber);
    event SaleListingRemoved(uint apartmentNumber);
    event FundsWithdrawn(uint apartmentNumber, uint256 amount);
    event ApartmentListedForSale(uint apartmentNumber, uint256 salePrice);
    event ApartmentSold(uint apartmentNumber, address newOwner, uint256 salePrice);
    event RentPaid(uint apartmentNumber, uint256 amount, address tenant);
    
    // Modificador para verificar o proprietário do apartamento
    modifier onlyOwner(uint _apartmentNumber) {
        require(apartments[_apartmentNumber].owner == msg.sender, "Somente o proprietario pode executar esta operacao.");
        _;
    }
    
    // Registrar um novo apartamento com número único
    function registerApartment(uint _apartmentNumber) external {
        require(!existingApartmentNumbers[_apartmentNumber], "Este numero de apartamento ja esta registrado.");
        
        apartments[_apartmentNumber] = Apartment({
            apartmentNumber: _apartmentNumber,
            owner: msg.sender,
            isForRent: false,
            isForSale: false,
            rentPrice: 0,
            salePrice: 0,
            currentTenant: address(0)
        });
        
        existingApartmentNumbers[_apartmentNumber] = true;
        
        emit ApartmentRegistered(_apartmentNumber, msg.sender);
    }
    
    // Disponibilizar o apartamento para aluguel
    function setApartmentForRent(uint _apartmentNumber, uint256 _rentPrice) external onlyOwner(_apartmentNumber) {
        Apartment storage apt = apartments[_apartmentNumber];
        require(!apt.isForRent, "Apartamento ja esta para aluguel.");
        require(!apt.isForSale, "Apartamento ja esta para venda.");
        require(apt.currentTenant == address(0), "Apartamento esta atualmente alugado.");
        
        apt.isForRent = true;
        apt.rentPrice = _rentPrice;
        
        emit ApartmentListedForRent(_apartmentNumber, _rentPrice);
    }

    // Remover a listagem para aluguel
    function removeRentListing(uint _apartmentNumber) external onlyOwner(_apartmentNumber) {
        Apartment storage apt = apartments[_apartmentNumber];
        require(apt.isForRent, "Apartamento nao esta para aluguel.");
        
        apt.isForRent = false;
        apt.rentPrice = 0;
        
        emit RentListingRemoved(_apartmentNumber);
    }

    // Alugar um apartamento
    function rentApartment(uint _apartmentNumber) external payable {
        Apartment storage apt = apartments[_apartmentNumber];
        require(apt.isForRent, "Apartamento nao esta disponivel para aluguel.");
        require(apt.currentTenant == address(0), "Apartamento ja esta alugado.");
        require(msg.value >= apt.rentPrice, "Valor do aluguel insuficiente.");
        
        apt.currentTenant = msg.sender;
        apt.isForRent = false;
        
        rentalAgreements[_apartmentNumber] = RentalAgreement({
            tenant: msg.sender,
            rentAmount: msg.value,
            startDate: block.timestamp
        });
        
        emit ApartmentRented(_apartmentNumber, msg.sender, msg.value);
    }
    
    // Pagamento de aluguel recorrente
    function payRent(uint _apartmentNumber) external payable {
        Apartment storage apt = apartments[_apartmentNumber];
        require(apt.currentTenant == msg.sender, "Somente o inquilino pode pagar o aluguel.");
        require(msg.value >= apt.rentPrice, "Valor do aluguel insuficiente.");
        
        rentalAgreements[_apartmentNumber].rentAmount += msg.value;
        
        emit RentPaid(_apartmentNumber, msg.value, msg.sender);
    }
    
    // Terminar o aluguel pelo proprietário
    function terminateRental(uint _apartmentNumber) external onlyOwner(_apartmentNumber) {
        Apartment storage apt = apartments[_apartmentNumber];
        require(apt.currentTenant != address(0), "Apartamento nao esta alugado.");
        
        apt.currentTenant = address(0);
        apt.isForRent = false;
        apt.rentPrice = 0;
        
        delete rentalAgreements[_apartmentNumber];
        
        emit RentalTerminated(_apartmentNumber);
    }

    // Terminar o aluguel pelo inquilino
    function tenantTerminateRental(uint _apartmentNumber) external {
        Apartment storage apt = apartments[_apartmentNumber];
        require(apt.currentTenant == msg.sender, "Somente o inquilino pode terminar o aluguel.");
        
        apt.currentTenant = address(0);
        apt.isForRent = false;
        apt.rentPrice = 0;
        
        delete rentalAgreements[_apartmentNumber];
        
        emit RentalTerminated(_apartmentNumber);
    }
    
    // Retirar fundos acumulados do aluguel
    function withdrawFunds(uint _apartmentNumber) external onlyOwner(_apartmentNumber) {
        RentalAgreement storage agreement = rentalAgreements[_apartmentNumber];
        require(agreement.rentAmount > 0, "Nao ha fundos para retirar.");
        
        uint256 amount = agreement.rentAmount;
        agreement.rentAmount = 0;
        
        payable(msg.sender).transfer(amount);
        
        emit FundsWithdrawn(_apartmentNumber, amount);
    }
    
    // Listar um apartamento para venda
    function setApartmentForSale(uint _apartmentNumber, uint256 _salePrice) external onlyOwner(_apartmentNumber) {
        Apartment storage apt = apartments[_apartmentNumber];
        require(!apt.isForRent, "Apartamento ja esta para aluguel.");
        require(!apt.isForSale, "Apartamento ja esta a venda.");
        require(apt.currentTenant == address(0), "Nao e possivel vender um apartamento alugado.");
        
        apt.isForSale = true;
        apt.salePrice = _salePrice;
        
        emit ApartmentListedForSale(_apartmentNumber, _salePrice);
    }

    // Remover a listagem para venda
    function removeSaleListing(uint _apartmentNumber) external onlyOwner(_apartmentNumber) {
        Apartment storage apt = apartments[_apartmentNumber];
        require(apt.isForSale, "Apartamento nao esta a venda.");
        
        apt.isForSale = false;
        apt.salePrice = 0;
        
        emit SaleListingRemoved(_apartmentNumber);
    }
    
    // Comprar um apartamento
    function buyApartment(uint _apartmentNumber) external payable {
        Apartment storage apt = apartments[_apartmentNumber];
        require(apt.isForSale, "Apartamento nao esta disponivel para venda.");
        require(msg.value >= apt.salePrice, "Valor insuficiente para compra.");
        
        address previousOwner = apt.owner;
        
        apt.owner = msg.sender;
        apt.isForSale = false;
        apt.salePrice = 0;
        
        payable(previousOwner).transfer(msg.value);
        
        emit ApartmentSold(_apartmentNumber, msg.sender, msg.value);
    }
    
    // Função para abrir a porta do apartamento
    function openDoor(uint _apartmentNumber) external view returns (bool) {
        Apartment storage apt = apartments[_apartmentNumber];
        
        // Verifica se o chamador é o proprietário e o apartamento não está alugado
        if (apt.owner == msg.sender && apt.currentTenant == address(0)) {
            return true;
        }
        
        // Verifica se o chamador é o inquilino atual
        if (apt.currentTenant == msg.sender) {
            return true;
        }
        
        return false;
    }
    
    // Função para receber Ether
    receive() external payable {}
    
    fallback() external payable {}
}
