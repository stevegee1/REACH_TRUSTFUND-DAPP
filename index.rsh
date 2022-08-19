'reach 0.1';

// Communication pattern among the participant of the DApp
// 1. Funder will have to pay the funds into the contract and set the timelock
// 2. After the timelock has been reached, the dapp send ready actions to the participants
// 3. The fund can only be withdrawn by the receiver during the set span of time for release
// 4. After the receiver time elapsed and the fund has not been claimed, then the fund can only
// be claimed by the Funder.
// 5. If not claimed by any of the above-mentioned, then anybody can withdraw the fund
// 6. If withdrawn by any of the above-mentioned, the program triggers received action


const common= {
  funded: Fun([], Null), //share the info that the lock has been funded
  ready: Fun([], Null), //share the info that the fund is ready to be released after certain time
  recvd: Fun([UInt], Null) //share the info that the fund has been received
}
export const main = Reach.App(() => {
  const funder = Participant('Funder', {
    ...common,
    getParams: Fun([], Object({
      receiverAddr: Address,
      payment: UInt,
      maturity: UInt,
      refund: UInt,
      dormant: UInt

    }))
    // Specify Alice's interact interface here

  });
  const receiver = Participant('Receiver', {
    ...common
    // Specify Bob's interact interface here
  });
  const  byStander= Participant('Bystander',{
    ...common
  })

  init();
  // The first one to publish deploys the contract
  funder.only(()=>{
    const {receiverAddr, payment, maturity, refund, dormant}= declassify(interact.getParams());
  })
  funder.publish(receiverAddr, payment, maturity,  refund, dormant)
       .pay( payment);
  receiver.set(receiverAddr);
  commit();
  each([funder, receiver, byStander],()=>{
    interact.funded();
  } );
  wait(relativeTime(maturity)); //everyone waits for the fund to mature
  const giveChance= (who, then)=> {
    who.only(()=>interact.ready()) ; 

    if (then) {
      who.publish()
        .timeout(relativeTime(then.deadline), ()=> then.after());
    }
    else {
      who.publish();
    }
    transfer(payment).to(who);
    commit();
    who.only(()=>  interact.recvd(payment));
    exit();
  };
  giveChance(receiver,{
    deadline: refund,
    after: ()=>giveChance(
      funder,
      {deadline: dormant,
      after: ()=>
    giveChance(byStander,false)}
    )
  });
  
});
